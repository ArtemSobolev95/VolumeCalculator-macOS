# Volume Calculator for IsiX and Horos (macOS)

Lesion volume from a diameter, and its change between a baseline and a follow-up study, in
**IsiX DICOM Viewer**. Ported from the OsiriX/Horos
[Volume Calculator](https://github.com/horosproject/horosplugins/tree/master/Volume%20Calculator)
plugin.

## Download

Current version: **1.0.0**.

| Viewer | Package | macOS | Mac |
|---|---|---|---|
| IsiX DICOM Viewer 6.0+ (GitHub build) | `VolumeCalculator-IsiX-1.0.0.zip` | 15 or later | Apple silicon and Intel |
| Horos 4.0.1 | `VolumeCalculator-Horos-1.0.0.zip` | 11 or later | Apple silicon and Intel |

Each package works on both kinds of Mac. The App Store version of IsiX loads no plugins; use the
[GitHub build of IsiX](https://github.com/ThalesMMS/IsiX-DICOM-Viewer-macOS/releases).

### Install

1. Quit the viewer.
2. Unzip the package and double-click **Install VolumeCalculator.command**.
   If macOS says the developer cannot be verified: System Settings › Privacy & Security ›
   *Open Anyway*, then double-click it again.
3. Open the viewer. *Plugins › Plugins Manager* should list VolumeCalculator as loaded.

## Use

1. Open the baseline and the follow-up study, each in its own 2D viewer.
2. In each, draw a line with the **Length** tool across the lesion. If an image has several
   lines, select the one to use.
3. *Plugins › ROI Tools › Volume Calculator*, or the toolbar button (right-click the toolbar ›
   *Customize Toolbar…* › drag **Volume Calculator** onto it).

The window shows, for each study, the source (patient · series), the study date, the diameter and
the volume (mm³ and mL); then the volume change (% and ×), the interval in days and the volume
doubling time, VDT = Δt · ln 2 / ln(V₂/V₁) (a halving time when the lesion shrank).

- The older study is the baseline; **Swap** exchanges them.
- The values follow the lines while you move or resize them. Deleting a line keeps its last value.
- A diameter can be typed (comma or point); a typed value no longer follows the line.
- **Reload from Viewers** picks the lines again; **Copy Results** puts a text summary on the
  clipboard for the report.
- Both lines on one image (one viewer) also work: no interval or doubling time then.

## How the lines are chosen

From the image shown in each open 2D viewer, oldest study first: the selected length ROI, else the
first one, one per viewer. If that gives fewer than two, a second line from a viewer already used.
The original could take the same ROI twice; that is fixed.

## Limits

The volume assumes a sphere (V = π·d³/6), as the original. For an elongated lesion it is only an
estimate, and errors in the diameter are cubed: 10 % in the diameter is about 33 % in the volume.
When the image has no pixel spacing, lengths are in pixels and no change is computed against mm.

## Build

Needs the Xcode command line tools (`xcode-select --install`). The plugin SDK headers are in
[`third_party/`](third_party). No nib: the window is built in code.

```sh
./build.sh install                   # IsiX build, installs into IsiX
TARGET=horos ./build.sh install      # Horos build, installs into Horos
TARGET=isix ./package.sh; TARGET=horos ./package.sh   # zips in dist/
```

Or double-click **Build IsiX version.command** / **Build Horos version.command** /
**Build release.command**.

Test of the arithmetic (plain C, runs anywhere):

```sh
cc -o tm tests/test_math.c Sources/VCMath.c -lm && ./tm
```
