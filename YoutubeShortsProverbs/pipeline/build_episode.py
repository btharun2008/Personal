#!/usr/bin/env python3
"""
Build one Shorts episode (hook clips -> question -> explanation -> payoff
clips -> CTA) into a single vertical MP4, from a YAML episode config.

Usage:
    python3 build_episode.py episodes/example-actions-speak-louder/episode.yaml

Requires ffmpeg/ffprobe on PATH, and the packages in requirements.txt.
"""
import argparse
import shutil
import subprocess
import sys
import textwrap
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageFont

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "C:\\Windows\\Fonts\\arialbd.ttf",
]


def find_font():
    for candidate in FONT_CANDIDATES:
        if Path(candidate).exists():
            return candidate
    return None


def wrap_text(text, width_px, fontsize, width_ratio=0.85, char_ratio=0.55):
    """Wrap text to fit width_px at the given fontsize (rough monospace estimate)."""
    max_chars = max(10, int((width_px * width_ratio) / (fontsize * char_ratio)))
    lines = []
    for paragraph in text.split("\n"):
        lines.extend(textwrap.wrap(paragraph, width=max_chars) or [""])
    return lines


def check_ffmpeg():
    for tool in ("ffmpeg", "ffprobe"):
        if shutil.which(tool) is None:
            sys.exit(
                f"error: `{tool}` not found on PATH. Install ffmpeg "
                "(e.g. `apt-get install ffmpeg` / `brew install ffmpeg`) "
                "before running this pipeline."
            )


def run(cmd):
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode != 0:
        sys.exit(
            "error running: "
            + " ".join(str(c) for c in cmd)
            + "\n\n"
            + result.stdout.decode(errors="replace")
        )


class Card:
    """A text card rendered to a still image, then turned into a short video."""

    def __init__(self, width, height, bg=(10, 10, 10), fg=(255, 255, 255)):
        self.width = width
        self.height = height
        self.bg = bg
        self.fg = fg
        self.font_path = find_font()

    def render(self, text, out_png, fontsize=72):
        img = Image.new("RGB", (self.width, self.height), self.bg)
        draw = ImageDraw.Draw(img)
        font = (
            ImageFont.truetype(self.font_path, fontsize)
            if self.font_path
            else ImageFont.load_default()
        )

        lines = wrap_text(text, self.width, fontsize)

        line_heights = [
            draw.textbbox((0, 0), line, font=font)[3]
            - draw.textbbox((0, 0), line, font=font)[1]
            for line in lines
        ]
        spacing = int(fontsize * 0.35)
        total_height = sum(line_heights) + spacing * (len(lines) - 1)
        y = (self.height - total_height) / 2

        for line, lh in zip(lines, line_heights):
            bbox = draw.textbbox((0, 0), line, font=font)
            line_width = bbox[2] - bbox[0]
            x = (self.width - line_width) / 2
            draw.text((x, y), line, font=font, fill=self.fg)
            y += lh + spacing

        img.save(out_png)


def image_to_clip(png_path, duration, out_mp4, resolution, fps):
    w, h = resolution
    run(
        [
            "ffmpeg", "-y",
            "-loop", "1", "-i", str(png_path),
            "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
            "-t", str(duration),
            "-vf", f"scale={w}:{h},setsar=1",
            "-r", str(fps),
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
            "-c:a", "aac", "-shortest", "-pix_fmt", "yuv420p",
            str(out_mp4),
        ]
    )


def trim_and_normalize(src, start, duration, out_mp4, resolution, fps,
                        overlay_text=None, font_path=None, workdir=None):
    w, h = resolution
    vf = (
        f"scale={w}:{h}:force_original_aspect_ratio=increase,"
        f"crop={w}:{h},setsar=1"
    )
    if overlay_text:
        fontsize = 64
        lines = wrap_text(overlay_text, int(w * 0.92), fontsize)
        textfile = Path(workdir) / f"{Path(out_mp4).stem}_overlay.txt"
        textfile.write_text("\n".join(lines))
        box_font = f":fontfile={font_path}" if font_path else ""
        vf += (
            f",drawtext=textfile='{textfile}'{box_font}:fontsize={fontsize}"
            ":fontcolor=white:line_spacing=8"
            ":box=1:boxcolor=black@0.55:boxborderw=20"
            ":x=(w-text_w)/2:y=h-(text_h*3)-40"
        )
    run(
        [
            "ffmpeg", "-y",
            "-ss", str(start), "-i", str(src),
            "-t", str(duration),
            "-vf", vf,
            "-r", str(fps),
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
            "-c:a", "aac", "-ar", "44100", "-ac", "2",
            "-pix_fmt", "yuv420p",
            str(out_mp4),
        ]
    )


def concat_clips(clip_paths, out_mp4, workdir):
    list_file = workdir / "concat_list.txt"
    with open(list_file, "w") as f:
        for p in clip_paths:
            f.write(f"file '{Path(p).resolve()}'\n")
    run(
        [
            "ffmpeg", "-y",
            "-f", "concat", "-safe", "0", "-i", str(list_file),
            "-c", "copy",
            str(out_mp4),
        ]
    )


def seconds_to_srt_ts(t):
    h = int(t // 3600)
    m = int((t % 3600) // 60)
    s = int(t % 60)
    ms = int(round((t - int(t)) * 1000))
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def write_srt(entries, out_path):
    with open(out_path, "w") as f:
        for i, (start, end, text) in enumerate(entries, 1):
            f.write(f"{i}\n{seconds_to_srt_ts(start)} --> {seconds_to_srt_ts(end)}\n{text}\n\n")


def build(config_path):
    check_ffmpeg()
    config_path = Path(config_path).resolve()
    base = config_path.parent
    cfg = yaml.safe_load(config_path.read_text())

    resolution = tuple(cfg.get("resolution", [1080, 1920]))
    fps = cfg.get("fps", 30)
    workdir = base / "_build"
    workdir.mkdir(exist_ok=True)
    card = Card(*resolution)
    font_path = card.font_path

    segments = []
    srt_entries = []
    t_cursor = 0.0

    # 1. Hook clips — overlay the phrase on the last one.
    hook_clips = cfg.get("hook_clips", [])
    if not (4 <= len(hook_clips) <= 5):
        print(f"warning: expected 4-5 hook_clips, got {len(hook_clips)}", file=sys.stderr)
    for i, clip in enumerate(hook_clips):
        out = workdir / f"hook_{i}.mp4"
        overlay = cfg.get("phrase_overlay") if i == len(hook_clips) - 1 else None
        trim_and_normalize(
            base / clip["file"], clip["start"], clip["duration"],
            out, resolution, fps, overlay_text=overlay, font_path=font_path,
            workdir=workdir,
        )
        segments.append(out)
        t_cursor += float(clip["duration"])

    # 2. The question card.
    question = cfg.get("question", "But what does it actually mean?")
    q_duration = float(cfg.get("question_duration", 2.0))
    card.render(question, workdir / "question.png", fontsize=80)
    q_clip = workdir / "question.mp4"
    image_to_clip(workdir / "question.png", q_duration, q_clip, resolution, fps)
    segments.append(q_clip)
    srt_entries.append((t_cursor, t_cursor + q_duration, question))
    t_cursor += q_duration

    # 3. The explanation — one card per line, evenly timed.
    explanation_lines = cfg.get("explanation", [])
    total_explain = float(cfg.get("explanation_duration", 3.0 * max(1, len(explanation_lines))))
    per_line = total_explain / max(1, len(explanation_lines))
    for i, line in enumerate(explanation_lines):
        card.render(line, workdir / f"explain_{i}.png", fontsize=64)
        clip = workdir / f"explain_{i}.mp4"
        image_to_clip(workdir / f"explain_{i}.png", per_line, clip, resolution, fps)
        segments.append(clip)
        srt_entries.append((t_cursor, t_cursor + per_line, line))
        t_cursor += per_line

    # 4. Payoff clips.
    payoff_clips = cfg.get("payoff_clips", [])
    if len(payoff_clips) < 2:
        print(f"warning: expected 2 payoff_clips, got {len(payoff_clips)}", file=sys.stderr)
    for i, clip in enumerate(payoff_clips):
        out = workdir / f"payoff_{i}.mp4"
        trim_and_normalize(
            base / clip["file"], clip["start"], clip["duration"],
            out, resolution, fps,
        )
        segments.append(out)
        t_cursor += float(clip["duration"])

    # 5. CTA card.
    cta = cfg.get("cta", "Follow for a new phrase every day")
    cta_duration = float(cfg.get("cta_duration", 2.5))
    card.render(cta, workdir / "cta.png", fontsize=72)
    cta_clip = workdir / "cta.mp4"
    image_to_clip(workdir / "cta.png", cta_duration, cta_clip, resolution, fps)
    segments.append(cta_clip)
    srt_entries.append((t_cursor, t_cursor + cta_duration, cta))
    t_cursor += cta_duration

    out_path = base / cfg.get("output", "output/final.mp4")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    concat_clips(segments, out_path, workdir)

    srt_path = out_path.with_suffix(".srt")
    write_srt(srt_entries, srt_path)

    print(f"done: {out_path}  ({t_cursor:.1f}s)")
    print(f"captions: {srt_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("config", help="Path to an episode.yaml file")
    args = parser.parse_args()
    build(args.config)
