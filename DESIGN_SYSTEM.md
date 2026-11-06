# Mobile design system

The app uses the Assiut National University logo in assets/images/logo.png,
Arabic labels, and RTL layout. lib/theme.dart defines the Material 3 theme
based on the university screens supplied by the user.

| Token | Light value | Use |
|---|---|---|
| Primary | #5A3824 | Brown brand and primary actions |
| Secondary | #8D5E3D | Bronze accents |
| Canvas | #F9F9FB | Page background |
| Warm surface | #F3EFEA | Inputs |
| Surface | #FFFFFF | Cards |
| Text | #2A211C | Body and headings |
| Success | #177A4E | Positive status |
| Warning | #8A5900 | Attention |
| Error | #B3261E | Errors |
| Page gutter | 16 dp | Padding |
| Card radius | 16 dp | Cards |
| Control radius | 12 dp | Inputs and buttons |

Dark mode uses a warm dark canvas and lighter brown/bronze controls. Typography
uses the Material hierarchy and system fonts, without remote font dependencies.

The shell has role-specific bottom navigation and a course/section selector.
Doctors can include all assigned sections; TAs and students select only sections
returned by their authenticated API. Pages scroll inside SafeArea with a maximum
content width of 760 dp. Rosters and gradebooks use paginated student cards.

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

Primary buttons have a minimum height of 48 dp. Scanner errors are visible, and
QR text input provides a manual alternative for local attendance testing.
Physical-device camera behavior still needs hands-on validation.

See [the role UI/UX review](docs/UI_UX_REVIEW.md) for current changes and evidence.
