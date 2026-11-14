# Scanner exit and manual-entry fix — 2026-11-06

The owner reported that the camera stayed active after leaving without scanning,
and that expanding manual entry produced a large grey area.

## Reproduced causes and changes

- Browser video tracks remained `live` after route exit. The installed
  `mobile_scanner` 7.4.3 reader stopped decoding without ending those tracks.
  ScanPage now explicitly owns startup/stop and releases its acquired browser
  streams on exit. Native builds use the controller's stop/dispose implementation.
- Startup awaiting browser permission is cancelled when leaving. A late permission
  grant immediately ends its stream. Previous cleanup completes before another
  scanner starts, so delayed startup cannot affect a new scanner route.
- Expanding manual entry raised `type 'bool' is not a subtype of type 'double?'`.
  ExpansionTile's stored boolean collided with the text field's scroll position.
  A distinct PageStorage key fixes the release error widget without adding height.
- `web` 1.1.2 became a direct dependency; the already-locked version was retained.

## Verification

- **36 Flutter tests passed**; analysis reported no issues; JavaScript release
  web build passed.
- **5 scanner browser regressions passed**, including exit without scanning,
  desktop/mobile manual entry and validation, late permission cleanup, and reopening
  after cancelled startup. Actual MediaStream states change from `live` to `ended`;
  unrelated tracks are preserved. [Results](../review/scanner-fix-results.json).
- **8 QR workflow browser checks passed again**, including decoding the doctor's
  actual QR image, PostgreSQL persistence, repeat scanning without duplicate rows,
  and reopening the stored receipt. [Results](../review/priority-workflow-results.json).

Reproduce with `server/.venv/Scripts/python.exe tool/role_checks/scanner_check.py`
and `server/.venv/Scripts/python.exe tool/role_checks/priority_check.py`.
Browser tests use real media tracks from generated video and an isolated database;
no physical-camera or complete accessibility certification is claimed.

## Visual QA

From the visual evidence, I observe a compact labelled manual text field and a
visible confirmation button beneath the expansion, replacing the grey error area.
The existing RTL layout, theme and camera preview height remain intact. Keyboard
entry and validation are exercised at 1531×715 and 400×900; screen-reader speech
and physical touch interaction remain outside this check.

- [Desktop](../screenshots/scanner-fix/manual-desktop.png)
- [Mobile](../screenshots/scanner-fix/manual-mobile.png)

The rebuilt preview is served at http://localhost:8080/. Refresh the existing tab
to replace the previously loaded application and camera session.
