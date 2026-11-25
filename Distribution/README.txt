Volume Calculator @VERSION@ — lesion volume from a diameter, and its change between two studies
================================================================================================

Takes the length of a line ROI as the diameter of a sphere, gives its volume (V = π·d³/6), and
compares a baseline with a follow-up study: volume change in %, ratio, interval between the study
dates and volume doubling time. A port of the OsiriX/Horos "Volume Calculator" plugin.

INSTALL
  Quit the viewer, double-click "Install VolumeCalculator.command", open the viewer.
  If macOS says the developer cannot be verified: System Settings > Privacy & Security > Open Anyway.

USE
  1. Open the baseline and the follow-up study, each in its own 2D viewer.
  2. In each, draw a line with the Length tool across the lesion (selected lines are preferred).
  3. Plugins > ROI Tools > Volume Calculator (or the toolbar button: right-click the toolbar >
     Customize Toolbar… and drag "Volume Calculator" onto it).
  4. The older study becomes the baseline. The values follow the lines as you move them.
     You can also type a diameter, use Swap, Reload from Viewers, and Copy Results (text for
     the report).

  The volume assumes a sphere: for an elongated lesion it is only an estimate, and a 10 % error
  in the diameter is about a 33 % error in the volume.
