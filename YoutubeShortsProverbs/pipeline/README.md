# Build pipeline

Turns a filled-in `episode.yaml` into one finished vertical MP4, matching
the 5-beat format described in the top-level README.

## Setup (one time)

```bash
# ffmpeg must be on PATH
sudo apt-get install ffmpeg      # Debian/Ubuntu
# or: brew install ffmpeg        # macOS

pip install -r pipeline/requirements.txt
```

## Per-episode workflow

1. **Scaffold a new episode** (copies the template, marks the phrase
   "Sourcing clips" in `proverbs-list.csv`):

   ```bash
   python3 pipeline/new_episode.py "Actions speak louder than words"
   # or: python3 pipeline/new_episode.py --next   (pops the next Idea row)
   ```

   This creates `episodes/<slug>/episode.yaml` and `episodes/<slug>/clips/`.

2. **Source your clips.** Drop the raw video files (already-cut scenes,
   or full files you'll trim by timestamp) into `episodes/<slug>/clips/`.

3. **Fill in `episode.yaml`**: for each hook/payoff clip set `file`
   (relative to the yaml), `start` (`HH:MM:SS` or seconds), and
   `duration` (seconds). Write the question, explanation lines, and CTA.

4. **Build it:**

   ```bash
   python3 pipeline/build_episode.py episodes/<slug>/episode.yaml
   ```

   This produces `episodes/<slug>/output/final.mp4` (1080×1920 by
   default) and a matching `.srt` caption file, by:
   - trimming + center-cropping each hook/payoff clip to vertical,
     burning the phrase onto the last hook clip,
   - rendering the question/explanation/CTA beats as text cards,
   - concatenating everything into one file.

5. Upload `final.mp4`, add `final.srt` as the caption track if the
   platform supports it, then mark the row `published_date` in
   `proverbs-list.csv`.

## Notes

- Re-running `build_episode.py` is safe — it overwrites `_build/` and
  `output/` in the episode folder.
- Want a different look? Tweak `Card.render()` (fonts/colors/margins) or
  the `drawtext` filter in `trim_and_normalize()` in `build_episode.py`.
- `_build/` holds intermediate per-beat clips — useful for debugging a
  specific beat, safe to delete.
