# Mobile design system extraction

## Source and conflicts

The checked-out MVC application is an Identity scaffold. Its shared layout (`../legacy-attendance-system/Views/Shared/_Layout.cshtml`) uses Bootstrap, a white header, and Google Inter. `wwwroot/css/site.css` is mostly template styling. The actual custom login tokens are in `../legacy-attendance-system/wwwroot/css/login.css`, with matching values in `register.css` and `forgot.css`. The planning document `../legacy-attendance-system/docs/04-ux-ui-specification.md` proposes a different navy/teal palette; this prototype gives the implemented login stylesheet precedence for recognizable color and uses the planning document for mobile spacing, accessibility, and navigation rules.

No university name or official logo was found. The available PNG files under `assets/team` are team images, not an institutional mark. “Attendance System” is a neutral temporary wordmark. The `Icons.school_rounded` glyph identifies the prototype; it is not presented as an official logo.

## Tokens and adaptation

| Element | Source value | Mobile application |
|---|---|---|
| Primary | `#2F6FED` | Brand blue; darker `#1C54C7` for accessible filled controls |
| Secondary | `#00BFA6` | Teal cue; darker `#007F70` for readable text/actions |
| Canvas | `#F5F6FA` | App background |
| Surface | `#FFFFFF` | Cards and inputs |
| Main text | `#1F2937` | Body and headings |
| Muted text | `#6B7280` | Darkened to `#596579` where needed for smaller labels |
| Type | Inter, 12/14/16/18/22/28 px | Material text hierarchy with Inter preference, system fallback when offline |
| Shapes | 8 px button and 12 px login card | 12 px controls, 16 px mobile cards, 16 px page gutter |
| Feedback | Focus ring and login field underline | Material focus states, visible status text plus icons, snackbars and confirmation dialogs |

The desktop navbar becomes role-specific bottom navigation (4–5 items). Course tables become stacked cards and status rows. Policy and grade data use labeled blocks instead of horizontal tables. Every primary control is at least 48 dp high. Pages scroll within SafeArea, and cards use flexible text columns. Light and dark theme colors are defined centrally in `lib/theme.dart`. The current app does not bundle Inter because the source project references it remotely rather than shipping a licensed font file; installed Inter is used where available with a system fallback.
