# Social — social and delivery UI

## Responsibilities

- Own social-facing UI such as the future inbox, feed, pen-pal surfaces, and
  Send Form.
- Emit typed output intents for App to coordinate; never construct or call
  Editor, Library, or App routes directly.
- Own system-responsive portrait/landscape adaptation when presented as a
  standalone component. When composed later as an Editor Workspace accessory,
  adapt within the region App assigns and inherit the workspace policy.

## Key files

- `SocialScreen.swift` — F-055 structural top-level shell and return intent.

## Not responsible for

- App navigation and active window policy.
- Document editing or persistence details.
- Mailbox/envelope persistence and delivery rules until their features begin.

## Next step (current stage)

- None. Concrete social and mailbox content remains deferred to v3+.

## Notes for AI changes

- Keep the v1 shell structural; do not invent feed, account, envelope, or
  networking behavior ahead of their roadmap features.
- Presentation context controls layout policy: standalone Social is
  system-responsive; an Editor Workspace accessory inherits Editor's outer
  document-directed policy.
