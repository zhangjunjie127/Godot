# Male character source frames

Each direction contains 12 transparent 128x128 PNG frames.
Edit the numbered frames, then run `tools/rebuild_player_male_sheets.py`.
Runtime row order: S, SE, E, NE, N, NW, W, SW.

Current frames were converted from `image-2-godot4.zip` at the authored 12 FPS.
Keep visible feet on pixel row 117 and keep each direction's body height stable across all 12 frames.
Reimport the original atlas with `python tools/import_player_male_idle.py path/to/image-2_spritesheet.png`; the importer follows each transparent character silhouette so hands crossing the authored direction guides are not clipped.
