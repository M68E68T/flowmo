# flowmo — instructions for coding agents

Read README.md, docs/PROJECT_BRIEF.md and docs/VALIDATION.md before changing code.
Speak German. The user is a beginner: explain concrete next actions briefly.

## Goal and status
Independently implemented macOS utility inspired by the supplied Tangerine video.
Swift Package; native AppKit/SwiftUI, not a website/Electron project.
Version 0.3 implements a floating radial menu during a Finder drag plus a
user-configurable modifier combination (default Shift), local image/document/PDF
conversion, crop, backgrounds and JPEG compression. Window and wheel opacity are
user-adjustable.
The user confirmed the functioning workflow ("funktioniert top"). A JPG conversion
from the restyled embedded wheel was also checked in the running app.
Do not claim pixel-perfect identity from a compressed video or full feature parity.
UI MUST follow the supplied video: frosted rounded ring sectors, narrow translucent
vertical editor windows, preview above compact controls. The layout follows the
video, the wording follows the system language.
Do not introduce dark dashboards, oversized headings or side-by-side editor layouts.

## Engineering
- macOS 13+, Swift 5.9+ language mode. No external dependencies.
- App/UI in Sources/Flowmo; processing and testable models in FlowmoCore.
- No uploads, telemetry, destructive source-file changes or silent overwrites.
- Run conversion off the main thread. Keep window/UI changes on MainActor.
- Reject unsupported and multipage-image inputs explicitly. PDF page export includes all pages.
- DOCX export is text/basic formatting, not exact PDF layout reconstruction.
- Observe only public drag pasteboard and mouse/modifier state. No private Finder APIs.
- The drag trigger stays restricted to modifier keys. Polling NSEvent.modifierFlags
  works mid-drag and needs no permission; a registered letter hotkey does not fire
  reliably during a drag session. Do not switch to a global keyboard monitor.
- Drag detection is always on while the app runs; there is no enable switch.
  Preview-only bundles simply never call drag.start(). Do not reintroduce a
  toggle for it.
- EmbeddedWheel installs AppKit tracking areas, so it highlights on hover even
  with SwiftUI's allowsHitTesting(false). Do not place it anywhere decorative:
  it then looks like a control that does nothing.
- Only the floating wheel is translucent. Its opacity sits on the NSPanel's
  alphaValue in GlobalDragController, not on SwiftUI .opacity, so the wheel keeps
  working as a drop target at low opacity. Windows never set alphaValue: letting
  them show through each other only cost readability. Do not reintroduce it.
- ReferenceWindow is movable by its background, and AppKit treats every
  transparent view as background. Any view that handles drags (canvas, crop,
  page thumbnails) must return mouseDownCanMoveWindow = false, or each stroke
  also moves the window.
- place() restores ReferenceWindow.preferredSize before positioning: right after
  contentViewController is set the window has a provisional size. Window
  controllers set shouldCascadeWindows = false, or AppKit moves them again.
- Every SwiftUI root view hosted in a window needs an explicit .frame(width:height:)
  matching the window, see ImageEditor.swift. AppKit otherwise adopts the hosting
  controller's intrinsic size and shrinks the window.
- Windows must never open on top of each other: transparent windows show through.
  Place secondary windows with WindowPlacement.beside, not center().
- Keep preview and save apart: nothing is stored before commit(_:). The settings
  window is rebuilt per open, so a discarded draft cannot survive in @State and
  closing needs no undo step.
- Only the floating wheel may hide the dashboard after a successful run. A click
  inside the dashboard must never make it disappear under the cursor, and errors
  must always bring it back.
- No Accessibility or screen-recording permissions are requested by current code.
- Explain new OS permissions before introducing an implementation that requires them.
- The UI is bilingual (de/en) via Resources/*.lproj and Bundle.main. Never hardcode
  user-visible text: add the key to BOTH Localizable.strings files. SwiftUI resolves
  plain string literals itself; use tr(_:_:) for AppKit titles and for texts with
  inserted values, where interpolating into the literal would corrupt the key.
- Preferences keys are flowmo*; the FLowmo*, Flosted* and OrbitDrop* keys exist only for the one-time
  migration in Preferences.load and must not be reused.
- Localizable.strings: only straight quotes delimit a value. A typographic
  closing quote inside a German string terminated it early, macOS then DISCARDED
  THE WHOLE FILE, and every label in the app fell back to its raw key. The key
  audit did not catch it because it checks presence, not syntax - build-app.sh
  now runs plutil -lint and aborts on a malformed file. Never bypass that.
- Undo records whole snapshots via UndoStack. The canvas fires `changed` on
  every mouse move for live feedback and `committed` only when a gesture ends;
  only the latter may reach the stack, or one drag becomes hundreds of steps.
- A DropDelegate must clear its state on EVERY exit, not just on success. A
  drag released beside a thumbnail left `dragging` set and reordered on the
  next move. SwiftUI also allows only one drop modifier per view, so reorder
  and import share one delegate.
- Drawn handles must always grab. The selection corners were painted for a
  while without mouseDown ever testing them - decoration that looks like a
  control. Test handles BEFORE the body, or edge handles stay unreachable.
- Preview and export share AnnotationRenderer.draw, so anything visible in the
  editor must end up in the file. Keep it that way: no export-only branches.
- Ask for an element's content only AFTER its frame exists. Opening the
  signature picker from the toolbar button had nothing to assign the result to,
  so the chosen signature was dropped and never reached the file.
- Assign content to a specific annotation id, never to whatever is selected:
  that turned a selected text element into a signature and lost the typed text.
- Only annotations passing isComplete(signatures:) are exported, and the save
  button is gated on them. Saving must never produce a file that looks exactly
  like the original.
- Redaction MUST remove content, never just cover it. AnnotationRenderer draws a
  page through only when it carries no .redaction; otherwise the page is
  rasterized via FileConverter.render and the bar painted onto the pixels. Never
  "optimize" this into plain drawing - the covered text would stay extractable.
  AnnotationTests guards this by reading page.string back.
- Program state does not belong in Preferences. The settings window has a Reset
  button, so anything stored there is wiped by it: IntroState keeps its own key
  for that reason. Add further flags the same way, not as Preferences fields.
- Start at login goes through SMAppService.mainApp only (LoginItem.swift). It is
  switched on automatically once per app location (LoginItemState, so a move to
  Applications re-registers); once the user turns it off it never comes back. A login launch stays in the menu bar:
  no dashboard, no introduction (LaunchPlan). Do not reintroduce a LaunchAgent.
- The product name is "flowmo", lowercase, in every visible place, file and
  bundle; Swift modules follow Swift casing (Flowmo, FlowmoCore). The mixed-case
  FLowmo* keys exist only for the one-time migration from 0.4.
- In PageManager the thumbnails are the source of truth, not the document:
  they may be reordered, trimmed or extended. Operate on PDFPage objects, never
  on document indices, or the wrong page gets changed.
- A drawn signature is an image, not a cryptographic signature. Do not describe
  it as a digital or qualified signature anywhere in the UI or docs.
- Stale drag pasteboard must not activate on a new ordinary mouse press.
- The wheel opens on the RISING EDGE of the trigger combination (TriggerLatch),
  never while the keys are merely held - holding would glue it to the pointer.
  Dismissing it must not disable the trigger: pressing the keys again has to
  reopen it within the same drag. Do not reintroduce a sticky suppress flag.
- Escape/cancel must not create files. Only the native drop handler starts conversion.
- Do not publish GitHub releases or change system settings without user instruction.
- Remote: github.com/M68E68T/flowmo (public). Commit freely, but push and
  publish releases only when the user explicitly asks for it.
- Icon and interface share the BrandMark vectors. Regenerate the committed
  Resources/flowmo.icns with scripts/make-icon.sh after changing BrandMark;
  never hand-draw a second version of the mark.

## Validation
Build: bash scripts/build-app.sh
Test: swift test --cache-path .build/cache --config-path .build/config --security-path .build/security
Restricted execution may need --disable-sandbox for SwiftPM's nested sandbox.
Run: dist/flowmo.app (or bash Starten.command).
Seventy-six tests cover processing, collision safety, PDF/DOCX, menu models,
modifier combinations, preference persistence and the UX regressions from
docs/UI_UX_AUDIT.md. FlowmoAppTests drives AppKit views offscreen with synthetic
events; it never posts events to the user's desktop.
App bundle is ad hoc signed, NOT Developer ID signed/notarized.
Keep caches/binaries out of future git commits; distributable binaries belong in Releases.

## Immediate next milestone
Keep the functional drag/drop path stable. Visually compare UI changes against the
actual supplied video, including Crop Image and Add BG windows. Then test editor
export, cancellation, multiple screens and real user files.
