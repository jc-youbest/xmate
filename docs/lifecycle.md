# Lifecycle & Callback Ordering

Why this doc exists: lifecycle and timing bugs recur as the app grows new
features and flows. The same questions keep coming back — *which callback
fires, in what order, and what state is the app in when it fires?* This
file is the shared mental model for that, plus a running **problem log**
of the major timing/lifecycle issues we hit and how they were (or were
not yet) resolved.

Scope: this doc is about the **platform** callback machinery (iOS /
SwiftUI / UIKit / PencilKit) and ordering. App-specific flow *design*
(how a flow was built + rejected alternatives) lives in
`architecture.md` (Flow design notes); this doc references it, never
restates it.

---

## 1. Mental model (for a non-iOS / embedded background)

Three things differ sharply from imperative UI (embedded C, Nokia S40):

**A hidden main run loop.** Like an embedded event loop, iOS runs one
event loop on the main thread (`UIApplication`). Touches, timers,
lifecycle transitions and drawing are all dispatched from it. You never
write the loop or `switch(event)`; you register callbacks and the system
calls them. `DispatchQueue.main.async { … }` means "post this block to
the main queue; run it on a later loop turn" — exactly like posting a
message to a queue in C.

**Declarative UI, not imperative.** You do not call create/draw/destroy
in sequence. You describe "given this state, the UI looks like this," and
SwiftUI diffs state changes and itself decides when to create, update or
destroy the real view objects. So `makeUIView` / `updateUIView` /
`dismantleUIView` are the framework *telling you* "I have now decided to
build / update / tear down a real view." You react; you do not control
the timing. State variables (`@State` / `@Published` / `@Binding`), when
changed, schedule a re-render; `onChange(of:)` is a "call me when this
value changed between renders" hook.

**First responder = global input focus.** iOS has a *responder chain* and
a single *first responder*, roughly "which control currently owns the
input focus." `becomeFirstResponder()` grabs focus — and it can **fail**
(returns `false`) if the view is not in a window, the window is not the
key window, or the app is not active.

---

## 2. The golden rule (PKToolPicker visibility)

> The PKToolPicker is visible **iff** a canvas `isFirstResponder` **and**
> its window `isKeyWindow` **and** the app is active.

`PKToolPicker` is bound to a responder (`setVisible(true,
forFirstResponder: canvas)`) and shows/hides automatically based on
whether that responder is the current first responder in the key window.
**Every ToolPicker bug traces to one of those three conditions not
holding at the moment activation ran.** Keep this rule in front of you for
any tool-picker symptom.

---

## 3. Callback roster (who fires each)

Four platform layers plus the project's own arbiter.

**App lifecycle — `UIApplication` notifications** (system posts on state
change):

- `willResignActiveNotification` — about to leave active (backgrounding,
  incoming call, app switcher). xmate uses it to `flushAllActive()`.
- `didBecomeActiveNotification` — became active (launch finished, or
  returned from background). xmate does **not** currently observe it.

**SwiftUI view lifecycle** (framework calls after diffing state):

- `body` recompute — any referenced `@State` / `@Published` / `@Binding`
  changed.
- `onAppear` / `onChange(of:)` — view appeared / a watched value changed.
- `UIViewRepresentable`: `makeUIView` (build the real UIView, once per
  instance), `updateUIView` (after make, and on every relevant state
  change), `dismantleUIView` (view removed from the tree).

**UIKit responder layer** (system calls on focus / window change):

- `becomeFirstResponder()` / `resignFirstResponder()` — grab / lose
  focus. `XmateCanvasView` overrides both to notify
  `DrawingSessionManager.canvasBecame/ResignedFirstResponder` on success.
- `didMoveToWindow()` — the view was attached to / detached from a window.

**PencilKit layer** (framework calls on draw / tool change):

- `PKCanvasViewDelegate.canvasViewDrawingDidChange` — strokes changed →
  forwarded to `DrawingSessionManager.canvasDrawingChanged` (save gate).
- `PKToolPickerObserver.toolPickerSelectedToolDidChange` — user picked a
  tool/color → `ToolPickerHost` pushes it to all registered canvases.

**Project arbiter — `DrawingSessionManager`** (driven by the above):

- `register` / `unregister` — canvas joins / leaves the registry.
- `setDesiredActive(pageID, role)` — "this page should be edited"
  (declared by the pagination views in onAppear / page change / mode
  switch).
- `makeActive(canvas)` — the real handoff: flush previous → reload →
  mark active → **bind ToolPicker** → `becomeFirstResponder`. This is the
  only entry point that makes the picker visible.

---

## 4. Ordering by scenario

### Cold launch → config → document → page 1

Roughly, on the main thread (→ means "triggers"):

1. Process starts, `@main xmateApp`. System builds `UIApplication`,
   `UIWindowScene`, `UIWindow`.
2. `WindowGroup { RootView()… }`. First access to `SettingsStore.shared`
   → `init` reads `UserDefaults` (**config load**: `paginationStyle`,
   default `.singlePage`). First access to `NoteStore.shared` → Core Data
   stack.
3. `RootView.body`: `document == nil` → placeholder.
4. Window shown → `RootView.onAppear` → `loadOrCreateDocument(…)`
   (**load document**). Sets `@State document` → re-render.
5. `RootView.body`: document set → `WritingScreen(document:)`.
6. `WritingScreen.body`: `pages` empty → no top bar; `.onAppear(loadPages)`.
7. `WritingScreen.onAppear` → `loadPages()`: `pages = store.pages(…)`,
   `currentPageIndex = 0` (**load pages**) → re-render.
8. `WritingScreen.body`: pages set → top bar shown; `.singlePage` →
   `SinglePagesView`.
9. `SinglePagesView.body`: `ForEach` builds one `PencilKitBridge` per
   page → SwiftUI calls `makeUIView` (create canvas, stamp pageID/role,
   gesture recognizers, load drawing) then `updateUIView` (schedules the
   deferred-async `register`).
10. `SinglePagesView.onAppear` → `setDesiredActive(page0, .single)`
    (registry may still be empty → just records the desire).
11. The real canvases are inserted into the hierarchy → attached to the
    window (`didMoveToWindow` fires internally).
12. The async `register` blocks run on the next loop turn → `register(page0)`
    matches the desired page → `makeActive(page0)` →
    `setVisible(true, forFirstResponder: page0)` + `page0.becomeFirstResponder()`.
13. At some point the system posts `didBecomeActiveNotification` (app
    active, window key).

**The crux is the relative order of step 12 and step 13, and it is NOT
deterministic** — both are async, scheduled inside framework internals.
If step 12's `becomeFirstResponder()` runs before the window is key / app
is active, it returns `false`, the first page never actually holds focus,
and (per the golden rule) the ToolPicker stays hidden. `makeActive`
ignores the return value and marks the page active anyway, and **nothing
retries** — so it stays broken until some later activation. See the
problem log (§5).

### Page turn (Single Page)

Finger swipe → `handleSwipeForward()` → `withAnimation { currentPageIndex += 1 }`.
`currentPageIndex` is `@State`, so:

- `SinglePagesView.body` recomputes → each page's offset recalculated
  (carousel pan). **Canvases are NOT rebuilt** — all `PencilKitBridge`s
  persist; `makeUIView`/`dismantleUIView` do not fire, only `updateUIView`
  (its inputs changed).
- `SinglePagesView.onChange(of: currentPageIndex)` → `setDesiredActive(page1)`
  → `makeActive(page1)` → bind picker + `becomeFirstResponder()`
  (**succeeds**, because the app is long-since active).
- `WritingScreen .onChange(of: currentPageIndex)` → `zoom.reset()`.

Why the picker is reliable here: activation happens well after the app is
active, so focus is grabbed cleanly.

### Mode switch (Single ↔ Continuous)

Top-bar toggle changes `paginationStyle` (`@Published`):

- `WritingScreen.body` recomputes → the `switch` picks the other branch.
  The old view subtree is removed, the new one built:
  - old bridges → `dismantleUIView` → `unregister` (sync-flush if still
    active, then drop from the ToolPicker).
  - new bridges → `makeUIView` → `updateUIView` (schedule `register`).
- new view `.onAppear` → `setDesiredActive(currentPage, newRole)`.
- new canvas registers → matches desired → `makeActive` → picker +
  `becomeFirstResponder`.

`desiredActive` is keyed on pageID **and** role so the incoming role's
canvas can be promoted while the outgoing role's canvas (same page) is
still active; `makeActive` flushes/demotes the outgoing one first. Picker
shows because, again, activation runs while the app is active.

### Zoom in, then back to 100%

Pinch → `MagnificationGesture.onChanged/onEnded` → `PageZoomModel`'s
`@Published userZoom` changes:

- `body` recomputes: current page's `scaleEffect` changes; pan callbacks
  flip between `nil` and non-`nil`, so `updateUIView` runs and
  enables/disables the finger-pan recognizer on the canvas.
- Double-tap / reset button → `userZoom` back to 1 → same path, recognizer
  disabled.

**Canvases are not rebuilt and focus does not move** — zoom is only a
`scaleEffect`/`offset` transform plus toggling one gesture recognizer.
`makeUIView`/`dismantleUIView` do not fire, the first responder is
unchanged, so **the ToolPicker is unaffected**. (This is a payoff of the
"all canvases stay alive" invariant — see `architecture.md`.)

### Background → foreground

- Backgrounding: system posts `willResignActiveNotification` →
  `flushAllActive()` (sync save). The system **may** also resign the
  canvas's first responder (picker disappears) → `resignFirstResponder`
  override → `canvasResignedFirstResponder` (clears anchor, schedules an
  async recovery). The view normally stays in the window, so
  `didMoveToWindow`/`makeUIView` do not fire.
- Foregrounding: system posts `didBecomeActiveNotification` (not observed
  today). If the system restored the first responder, the picker returns
  automatically; if not, recovery depends on that earlier async block
  running while the app is active — the same timing uncertainty as launch.

---

## 5. Problem log

Major lifecycle/timing problems, newest first. Record the symptom, what is
actually known, what was tried and rejected, and the current status — so a
future session does not re-walk the same dead ends.

### ToolPicker missing on the first page at cold launch — STATUS: OPEN (2026-06)

**Symptom.** On a fresh launch into page 1, the PKToolPicker does not
appear. Turning to page 2 (or switching pagination style) makes it appear,
after which it stays correct.

**Key clue.** A page turn reliably fixes it. A page turn re-runs
`makeActive` at a time when the app is already active. This points at
**activation timing, not registration**: the first `makeActive` at launch
runs while the app/window is not yet active+key, so its
`becomeFirstResponder()` fails (golden rule, §2), and `makeActive` neither
checks the result nor retries.

**Rejected / insufficient fixes (both failed on device):**

1. *Drive registration off `XmateCanvasView.didMoveToWindow`* instead of
   the deferred async in `updateUIView`. No effect — registration was
   never the problem; window-attach still precedes window-key, so the
   first `becomeFirstResponder` failed regardless.
2. *Observe `UIApplication.didBecomeActiveNotification` and re-run
   `makeActive` on the desired-active canvas.* Also failed on device.
   Suspected reason: `didBecomeActive` likely fires before the canvas is
   registered / `setDesiredActive` is set (the document/page load happens
   in onAppear callbacks), so the re-assert finds nothing — yet the later
   registration `makeActive` still did not show the picker. This means the
   exact failing condition is **not yet confirmed.**

**Current best hypothesis (unconfirmed).** At the first activation one of
the golden-rule conditions is not met, and/or `setVisible(forFirstResponder:)`
being called *before* `becomeFirstResponder()` does not re-present the
picker for a responder that becomes first responder afterwards. We have not
proven which.

**Agreed next step: instrument before changing logic.** Add temporary
timestamped logs to confirm the failing condition rather than guessing:

- in `makeActive`: the return value of `becomeFirstResponder()`,
  `UIApplication.shared.applicationState`, and `canvas.window?.isKeyWindow`;
- one line each in `register`, `setDesiredActive`,
  `canvasBecame/ResignedFirstResponder`, and a temporary `didBecomeActive`
  observer.

Run cold launch, then one page turn, and compare the two log windows: it
will show exactly which of the three golden-rule conditions is missing at
launch, and whether `didBecomeActive` fires before or after registration.
Fix only after that is established.
