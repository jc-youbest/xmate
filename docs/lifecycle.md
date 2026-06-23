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

### Continuous zoomed pan lag — STATUS: DIAGNOSED; NATIVE PROTOTYPE PLANNED (2026-06)

**Symptom.** Continuous Page finger pan is seriously laggy while zoomed;
Single Page's native zoom/pan remains smooth.

**Confirmed mechanism (code audit).** Continuous routes every pan update from
the current canvas recognizer into `PageZoomModel.panOffset`, an `@Published`
value. That invalidates the SwiftUI screen and reapplies `scaleEffect` /
`offset` to the complete Continuous stack. The `.equatable()` boundary avoids
a per-frame `PencilKitBridge.updateUIView` storm, but it cannot avoid moving
the enclosing multi-page hierarchy and its persistent canvases. Single Page
does not use this path: its `UIScrollView` owns `zoomScale` and `contentOffset`
inside UIKit.

**Decision.** Prototype persistent inner native scroll views per Continuous
page behind a feature flag; freeze the outer scroll while the current inner
page is zoomed. Preserve the same canvas identity, active-page handoff,
ToolPicker ownership, and Pencil-only drawing. A single native scroll zooming
the whole stack was rejected for the first prototype because it compromises
bounded-page semantics. The settled design is in `architecture.md`; staged
delivery is F-059 in `roadmap.md`. Single Page and `ZoomablePage` remain
untouched until the Continuous path independently passes device acceptance.

### Single Page zoomed edit menu during double-tap reset — STATUS: RESOLVED (2026-06)

**Symptom.** In Single Page, after zooming above 100%, a finger tap could
raise PencilKit's **Select All / Insert Space** menu, and a finger double-tap
intended to reset the page to 100% could also leak into that menu path. This
conflicted with the zoomed page's navigation-first contract: fingers should
pan, pinch, or reset the view, while Apple Pencil continues drawing.

**Confirmed root cause.** The edit menu is hosted by PencilKit's private
`PKTiledView` through `UIEditMenuInteraction`, not by `XmateCanvasView`. Its
trigger came from tap recognizers on the private `PKSelectionGestureView`.
Consequently, handling only the app canvas's responder actions or touch
delivery did not control the owner of the menu interaction.

**Rejected attempts.** Setting `cancelsTouchesInView` and
`delaysTouchesBegan` on the app double-tap recognizer was insufficient: the
PencilKit selection tap path could still win or complete independently.
Returning `false` from `XmateCanvasView.canPerformAction` was also
insufficient because the menu actions are routed through
`PKTiledView` / `UIEditMenuInteraction`, not the canvas override.

**Final fix.** `ZoomablePage` coordinates directly with the PencilKit
selection tap recognizers. First, `require(toFail:)` relationships make those
taps wait for the app's finger double-tap reset recognizer, giving reset
priority. Second, while `zoomScale` is above `minimumZoomScale`, the selection
tap recognizers are disabled; they are restored when zoom returns to minimum.
The coordination is re-applied after zoom relayout in case PencilKit rebuilds
its private selection subtree. It never visits or changes Apple Pencil drawing
recognizers. Single Page's native `UIScrollView` zoom/pan remains unchanged;
`ContinuousPagesView`, `PageZoom`, and `PencilKitBridge` were not changed.
The settled interaction design is recorded in `architecture.md` (Flow design
notes → Single Page zoomed edit-menu arbitration).

**Device verification (iPad 8th generation + Apple Pencil 1):**

- At 100%, a finger single-tap still shows **Select All / Insert Space**.
- After zooming in, a finger single-tap does not show the menu.
- After zooming in, a finger double-tap resets to 100% without showing the
  menu.
- After reset to 100%, a finger single-tap can show the menu again.
- Apple Pencil drawing still works.
- Finger pan and pinch zoom remain smooth.

### ToolPicker missing on the first page at cold launch — STATUS: RESOLVED (2026-06)

**Confirmed root cause (from the `[TP]` device log).** The full cold-launch
log was: 7 canvases `register` (app=inactive), then `didBecomeActive` with
`desiredPage=nil` — and **no `setDesiredActive`, no `register→promote`, no
`makeActive`, no `canvasBecameFR` at all.** So at launch `makeActive` never
runs and the picker is never bound. The earlier A/B debate
(becomeFirstResponder timing / setVisible ordering) was a red herring —
execution never reached `becomeFirstResponder`. It also explains why the
`didBecomeActive` re-assert attempt did nothing: `desiredPage` was `nil`.

Why the desired page is never declared: `SinglePagesView`'s one-shot
`.onAppear → syncDesiredActive()` fires while `pages` is still empty (the
frame before `WritingScreen.loadPages` runs), so its `guard !pages.isEmpty`
bails. `pages` then populates and the canvases register, but `onAppear`
does not fire again, so `setDesiredActive` is never called. A page turn
calls it via `onChange(of: currentPageIndex)` — hence "page 2 fixes it."
Both pagination views share this latent bug.

**Fix.** `WritingScreen` gates the canvas area (the pagination view) on
`!pages.isEmpty`, so the pagination view is created once, with pages
present, and its `onAppear` declares the desired page at launch. Confirmed
on device: the trace then showed `setDesiredActive` → `register→promote` →
`makeActive becameFR=true` and the picker appeared. The durable design rule
is recorded in `architecture.md` (Flow design notes → Activation bootstrap).

**Findings worth keeping (so they are not re-litigated):**

- The earlier "first-responder timing" framing was a red herring —
  execution never reached `becomeFirstResponder` at launch, because
  `makeActive` never ran at all.
- The confirming trace showed `makeActive … becameFR=true keyWin=true`
  while `app=inactive`: **`becomeFirstResponder` succeeds before the app is
  active, as long as the canvas's window is key.** "Wait for the app to
  become active" was never needed; only the desired-page declaration was.
- Two fixes that did NOT work — do not retry them: (1) driving registration
  off `XmateCanvasView.didMoveToWindow` (registration was never the
  problem); (2) a `didBecomeActiveNotification` re-assert (it found
  `desiredPage=nil` and did nothing — because the real bug was that the
  desired page was never declared).

**The trace lives on.** The temporary `[TP]` instrumentation was
productionised into `EditorTrace` (`DrawingSessionManager.swift`):
DEBUG-only, OFF by default, compiles to nothing in release. To trace this
path again (launch / foreground / paging timing), set
`EditorTrace.isEnabled = true` and filter the `EditorLifecycle` category in
Console.app. Probe points: `register`, `setDesiredActive`, `makeActive`
(logs `becomeFirstResponder`'s result + `isKeyWindow` + `inWindow`),
`canvasBecame/ResignedFirstResponder`, and `ToolPickerHost.setActiveCanvas`.
