# Mobile design system

The app uses the Assiut National University logo in assets/images/logo.png,
Arabic labels, and RTL layout. lib/theme.dart defines the Material 3 theme
based on the university screens supplied by the user.

| Token | Light value | Use |
|---|---|---|
| Primary | #5A3824 | Brown brand and primary actions |
| Secondary | #8D5E3D | Bronze accents |
| Canvas | #F8F6F2 | Page background |
| Warm surface | #FCFBF9 | Inputs |
| Surface | #FFFFFF | Cards |
| Text | #302A25 | Body and headings |
| Success | #177A4E | Positive status |
| Warning | #8A5900 | Attention |
| Error | #B3261E | Errors |
| Page gutter | 20 dp | Padding |
| Card radius | 20 dp | Cards |
| Control radius | 14 dp | Inputs and buttons |

Dark mode uses a warm dark canvas and lighter brown/bronze controls. Typography
uses bundled Noto Sans Arabic with Noto Sans for Latin characters. Both the UI
and exported PDFs load fonts from local assets, with their OFL license retained.

The shell uses role-specific bottom navigation below 960 dp and an extended
navigation rail on wider screens. A course/section selector shows the active scope.
Login switches to a two-panel layout at 900 dp. Dashboard actions become two
columns at 640 dp; summary metrics remain readable on narrow screens.
Doctors can include all assigned sections; TAs and students select only sections
returned by their authenticated API. Pages scroll inside SafeArea with a maximum
content width of 1100 dp. Rosters and gradebooks use paginated student cards.

Each role has a task-focused home screen with its primary action above the
summary metrics. All roles have an attendance destination; students choose when
to open the scanner. TAs can enter an assigned section workspace directly.
Account-specific course/section/theme preferences are restored against the
current permitted assignments.

lib/widgets/common.dart supplies loading, empty, error/retry, and refresh states.
Write actions wait for the API before showing success. Status labels accompany
icons. Grade fields distinguish zero from missing. Missing operational records
produce empty screens instead of invented data.

Refresh preserves the last loaded form and its controllers until fresh data
arrives. A failed refresh retains input and offers retry/dismiss controls.
Grade paging/manual refresh and partial attendance exits require explicit
discard decisions. Grade save/publication and attendance finalization use pinned
footers; they remain visible while the roster scrolls. Status banners explain
unsaved edits, saved corrections awaiting publication and incomplete totals.

Primary buttons have a minimum height of 52 dp. Scanner errors are visible, and
QR text input provides a manual alternative for local attendance testing.
Physical-device camera behavior still needs hands-on validation.

See [the role UI/UX review](docs/UI_UX_REVIEW.md) for current changes and evidence.


The refined shell uses ivory canvas, outlined white cards, dark brown welcome
panels and muted gold accents. Shared icon tiles, heading weights and spacing
keep authentication, rosters, grading, quizzes and reports consistent. Async card
actions surface errors; new notices replace stale snackbar messages.

Attendance draft saving and finalization share a pinned footer. Draft marks are
persisted separately from official records and carry revision checks. Quiz lists
refresh every 10 seconds, with scheduled/draft/cancelled/closed states explained.
Student reports show published totals and complete attendance history. PDF tables
use explicit direction for Arabic names and Latin identifiers/numeric values.

Flutter owns RTL layout; the outer HTML container retains default direction so
browser accessibility hit areas align with the painted Flutter controls.

Current screenshots and validation: [UI_REFINEMENT.md](docs/UI_REFINEMENT.md).
