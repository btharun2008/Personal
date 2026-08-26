# Proverbs & Phrases Shorts — Channel Kit

A YouTube Shorts format that teaches English proverbs and idioms through
movie/TV clips. Every video follows the same five-beat structure so the
channel builds a recognizable identity fast.

## The Format (target: 45–60 seconds)

| # | Beat | Length | What happens |
|---|------|--------|--------------|
| 1 | **Hook — clip barrage** | ~12–15s | 4–5 quick clips (2–3s each) from different movies/shows where a character says the proverb/phrase. No explanation yet — just rapid-fire proof that "everyone says this." Overlay the phrase as text on the first or last clip. |
| 2 | **The question** | ~3–5s | Cut to black or a text card: *"But what does it actually mean?"* This is the curiosity gap that stops the scroll. |
| 3 | **The explanation** | ~15–20s | Voiceover + on-screen text: plain-English meaning, (optionally) origin, and a one-line example of how to use it in a sentence. |
| 4 | **Payoff — closing clips** | ~10s | 2 more clips of the phrase in context, now that the viewer understands it — reframes them as "aha, that's what they meant." |
| 5 | **CTA** | ~2s | "Follow for a new phrase every day" + on-screen subscribe prompt. |

See `episode-template.md` for a fill-in-the-blank script sheet, and
`sample-episode.md` for a fully worked example.

## Workflow per episode

1. Pick a proverb/phrase from `proverbs-list.csv` (status column tracks progress).
2. Scaffold it: `python3 pipeline/new_episode.py --next` (or pass a phrase
   directly) — creates `episodes/<slug>/episode.yaml` + a `clips/` folder
   and marks the CSV row "Sourcing clips".
3. Search for clips where it's spoken verbatim (or near-verbatim) —
   subtitle-search sites, script databases, or scrubbing scenes you
   already know. Drop the raw files into `episodes/<slug>/clips/` and
   note the timestamps in `episode.yaml`.
4. Write the explanation beat directly in `episode.yaml` (2–3 short lines,
   no jargon).
5. Build it: `python3 pipeline/build_episode.py episodes/<slug>/episode.yaml`
   — auto-crops everything to vertical, burns the phrase onto the hook,
   renders the question/explanation/CTA cards, and concatenates the
   final MP4 + an SRT caption file.
6. Upload, publish, log the result (`published_date` in the CSV).

See `pipeline/README.md` for setup and details.

## Copyright / fair use — read before publishing

Using commercial movie/TV clips is the highest-risk part of this format.
A few things worth deciding up front rather than after a strike:

- **Content ID claims are likely even under fair use.** Fair use is a legal
  defense, not a filter YouTube applies automatically — expect claims that
  mute audio or redirect revenue, and budget for disputing or living with them.
- **Transformative use helps your case**: short clips (a few seconds each),
  combined with your own commentary/analysis (the explanation beat) and
  new context, is a stronger fair-use position than long, unaltered scenes.
  Keep clips as short as the joke/proof needs — don't linger.
- **Avoid full scenes or anything that could substitute for watching the
  work.** You're illustrating a phrase, not re-airing the movie.
- **Consider a hybrid approach** for episodes where clip rights are murky:
  use royalty-free/stock footage, text animation, or your own re-enactment
  for the explanation beat, and reserve licensed-feeling clips for the hook.
- This isn't legal advice — if the channel starts generating real revenue,
  a quick consult with someone who knows fair use case law is worth it.

## File map

- `episode-template.md` — blank script sheet (human-readable planning doc), copy per episode.
- `sample-episode.md` — one full worked example ("Actions speak louder than words").
- `proverbs-list.csv` — starter backlog of 50 phrases with tracking columns.
- `pipeline/` — scripts that turn a filled-in episode config into the final MP4.
- `episodes/` — one folder per episode (config, raw clips, build output).
