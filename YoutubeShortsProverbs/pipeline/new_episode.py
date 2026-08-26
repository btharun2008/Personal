#!/usr/bin/env python3
"""
Scaffold a new episode folder from the template, and mark it as
in-progress in proverbs-list.csv.

Usage:
    python3 new_episode.py "Actions speak louder than words"
    python3 new_episode.py --next     # pop the next "Idea" row from the CSV
"""
import argparse
import csv
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_DIR = ROOT / "episodes" / "_template"
EPISODES_DIR = ROOT / "episodes"
CSV_PATH = ROOT / "proverbs-list.csv"


def slugify(phrase):
    slug = re.sub(r"[^a-z0-9]+", "-", phrase.lower()).strip("-")
    return slug[:60]


def next_idea_phrase():
    rows = list(csv.DictReader(CSV_PATH.open()))
    for row in rows:
        if row.get("status", "").strip().lower() == "idea":
            return row["phrase"]
    sys.exit("no rows with status=Idea left in proverbs-list.csv")


def mark_status(phrase, status):
    rows = list(csv.DictReader(CSV_PATH.open()))
    fieldnames = rows[0].keys() if rows else []
    changed = False
    for row in rows:
        if row["phrase"].strip().lower() == phrase.strip().lower():
            row["status"] = status
            changed = True
    if not changed:
        print(f"warning: '{phrase}' not found in proverbs-list.csv, skipping status update",
              file=sys.stderr)
        return
    with CSV_PATH.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def scaffold(phrase):
    slug = slugify(phrase)
    dest = EPISODES_DIR / slug
    if dest.exists():
        sys.exit(f"error: {dest} already exists")

    shutil.copytree(TEMPLATE_DIR, dest)
    (dest / "clips").mkdir(exist_ok=True)
    (dest / "clips" / ".gitkeep").touch()

    episode_yaml = dest / "episode.yaml"
    text = episode_yaml.read_text()
    text = text.replace('title: "Phrase goes here"', f'title: "{phrase}"')
    text = text.replace('phrase_overlay: "Phrase goes here"', f'phrase_overlay: "{phrase}"')
    episode_yaml.write_text(text)

    mark_status(phrase, "Sourcing clips")
    print(f"created {dest}")
    print(f"next: fill in {episode_yaml}, add clips under {dest / 'clips'}/")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("phrase", nargs="?", help="Exact phrase text (matches proverbs-list.csv)")
    group.add_argument("--next", action="store_true", help="Use the next Idea-status row in the CSV")
    args = parser.parse_args()

    phrase = next_idea_phrase() if args.next else args.phrase
    scaffold(phrase)
