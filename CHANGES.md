# Changes

## 1.0.1

- Fixed: diameters read from line ROIs were 10× too small (the viewer gives lengths in cm; they
  were taken as mm), so volumes were 1000× too small. Typed diameters were not affected.

## 1.0.0 — first release

- Port of the OsiriX/Horos Volume Calculator plugin to IsiX DICOM Viewer (GitHub build, macOS 15+),
  universal (Apple silicon and Intel). Horos 4 build (macOS 11+) from the same source.
- As the original: two length ROIs (one per viewer, oldest study first, selected ROIs preferred)
  give two diameters, sphere volumes V = π·d³/6 and the change in % and ×; live update while
  the ROIs are edited.
- Fixed: the same ROI could be taken as both diameters; the window stayed alive after closing.
- Added: volume in mL, interval between the study dates, volume doubling (or halving) time,
  diameters typed by hand (locale decimal separator), Swap, Reload from Viewers, Copy Results,
  a note when the image has no pixel spacing (lengths in pixels). Window built in code, no nib.
