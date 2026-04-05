"""
Running Health Review — FastAPI backend
Parses Apple Health export and analyses runs with Claude.
"""

import os
import zipfile
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from io import BytesIO
from math import floor
from typing import Optional

import anthropic
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

app = FastAPI(title="Running Health Review")

# ── Static files ──────────────────────────────────────────────────────────────

app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/")
def index():
    return FileResponse("static/index.html")


# ── Models ────────────────────────────────────────────────────────────────────


class RunWorkout(BaseModel):
    date: str          # ISO-8601
    distance_km: float
    duration_secs: int
    calories: Optional[float] = None
    hr_avg: Optional[int] = None
    hr_min: Optional[int] = None
    hr_max: Optional[int] = None
    elevation_gain_m: Optional[float] = None
    # Derived — computed server-side for convenience
    formatted_distance: str
    formatted_duration: str
    formatted_pace: str


class AnalyseRequest(BaseModel):
    workouts: list[RunWorkout]
    mode: str = "single"   # "single" or "trend"
    target_index: int = 0  # which workout to analyse in "single" mode


# ── Health data parsing ───────────────────────────────────────────────────────


def _fmt_distance(km: float) -> str:
    return f"{km:.2f} km"


def _fmt_duration(secs: int) -> str:
    h = secs // 3600
    m = (secs % 3600) // 60
    s = secs % 60
    return f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"


def _fmt_pace(secs: int, km: float) -> str:
    if km <= 0:
        return "—"
    pace = secs / km
    return f"{floor(pace / 60)}:{int(pace % 60):02d} /km"


def _parse_date(raw: str) -> str:
    """Normalise Apple Health date strings to ISO-8601."""
    for fmt in ("%Y-%m-%d %H:%M:%S %z", "%Y-%m-%d %H:%M:%S"):
        try:
            return datetime.strptime(raw, fmt).isoformat()
        except ValueError:
            pass
    return raw


def _parse_xml(xml_bytes: bytes) -> list[RunWorkout]:
    workouts: list[RunWorkout] = []

    for event, elem in ET.iterparse(BytesIO(xml_bytes), events=("end",)):
        if elem.tag != "Workout":
            elem.clear()
            continue

        if "Running" not in elem.get("workoutActivityType", ""):
            elem.clear()
            continue

        # Duration
        dur_raw = float(elem.get("duration") or 0)
        dur_unit = elem.get("durationUnit", "min")
        duration_secs = int(dur_raw * 60 if dur_unit == "min" else dur_raw)

        # Distance
        dist_raw = float(elem.get("totalDistance") or 0)
        dist_unit = elem.get("totalDistanceUnit", "km").lower()
        if dist_unit in ("mi", "mile", "miles"):
            distance_km = dist_raw * 1.60934
        else:
            distance_km = dist_raw

        if distance_km < 0.1 or duration_secs < 60:
            elem.clear()
            continue

        # Calories
        cals = float(elem.get("totalEnergyBurned") or 0) or None

        # Heart rate & elevation from WorkoutStatistics
        hr_avg = hr_min = hr_max = elev = None
        for stats in elem.findall("WorkoutStatistics"):
            t = stats.get("type", "")
            if t == "HKQuantityTypeIdentifierHeartRate":
                hr_avg = int(float(stats.get("average") or 0)) or None
                hr_min = int(float(stats.get("minimum") or 0)) or None
                hr_max = int(float(stats.get("maximum") or 0)) or None
            elif t == "HKQuantityTypeIdentifierRunningPower":
                pass  # could use later
            elif "Elevation" in t or "Altitude" in t:
                elev = float(stats.get("sum") or 0) or None

        workout = RunWorkout(
            date=_parse_date(elem.get("startDate", "")),
            distance_km=round(distance_km, 3),
            duration_secs=duration_secs,
            calories=round(cals) if cals else None,
            hr_avg=hr_avg,
            hr_min=hr_min,
            hr_max=hr_max,
            elevation_gain_m=round(elev, 1) if elev else None,
            formatted_distance=_fmt_distance(distance_km),
            formatted_duration=_fmt_duration(duration_secs),
            formatted_pace=_fmt_pace(duration_secs, distance_km),
        )
        workouts.append(workout)
        elem.clear()

    # Most recent first
    return sorted(workouts, key=lambda w: w.date, reverse=True)


# ── Upload endpoint ───────────────────────────────────────────────────────────


@app.post("/api/parse", response_model=list[RunWorkout])
async def parse_health_export(file: UploadFile = File(...)):
    """
    Accept an Apple Health export ZIP (or the raw export.xml).
    Returns up to 50 most recent running workouts.
    """
    data = await file.read()

    if file.filename and file.filename.lower().endswith(".zip"):
        try:
            zf = zipfile.ZipFile(BytesIO(data))
        except zipfile.BadZipFile:
            raise HTTPException(400, "Not a valid ZIP file.")

        xml_name = next(
            (n for n in zf.namelist() if n.endswith("export.xml")),
            None,
        )
        if not xml_name:
            raise HTTPException(400, "export.xml not found inside the ZIP.")
        xml_bytes = zf.read(xml_name)
    elif file.filename and file.filename.lower().endswith(".xml"):
        xml_bytes = data
    else:
        raise HTTPException(400, "Please upload export.zip or export.xml from Apple Health.")

    try:
        workouts = _parse_xml(xml_bytes)
    except ET.ParseError as e:
        raise HTTPException(422, f"XML parse error: {e}")

    return workouts[:50]


# ── Analysis endpoint ─────────────────────────────────────────────────────────


def _build_single_prompt(workouts: list[RunWorkout], idx: int) -> str:
    w = workouts[idx]
    date = datetime.fromisoformat(w.date).strftime("%A, %d %b %Y %H:%M")
    history = [x for i, x in enumerate(workouts) if i != idx][:8]

    lines = [
        "You are an expert running coach. Analyse this run and provide specific, actionable coaching advice.\n",
        f"## Today's Run — {date}",
        f"- Distance: {w.formatted_distance}",
        f"- Duration: {w.formatted_duration}",
        f"- Avg Pace: {w.formatted_pace}",
    ]
    if w.calories:
        lines.append(f"- Calories: {w.calories:.0f} kcal")
    if w.elevation_gain_m:
        lines.append(f"- Elevation Gain: {w.elevation_gain_m:.0f} m")
    if w.hr_avg:
        lines.append(f"- Avg Heart Rate: {w.hr_avg} bpm")
    if w.hr_min and w.hr_max:
        lines.append(f"- HR Range: {w.hr_min}–{w.hr_max} bpm")

    if history:
        lines.append(f"\n## Recent Training ({len(history)} prior runs)")
        for r in history:
            d = datetime.fromisoformat(r.date).strftime("%d %b")
            line = f"- {d}: {r.formatted_distance} in {r.formatted_duration} @ {r.formatted_pace}"
            if r.hr_avg:
                line += f", HR {r.hr_avg} bpm"
            lines.append(line)

    lines += [
        "\nPlease provide a structured coaching report with these sections:",
        "**1. Run Summary** — brief quality assessment",
        "**2. Pacing Analysis** — was effort well-distributed?",
        "**3. Heart Rate Analysis** — zones, appropriateness (if data available)",
        "**4. Compared to Recent Runs** — progress or regression",
        "**5. Top 3 Improvement Tips** — specific and actionable",
        "**6. Suggested Next Workout** — a concrete recommendation",
    ]
    return "\n".join(lines)


def _build_trend_prompt(workouts: list[RunWorkout]) -> str:
    lines = [
        f"You are an expert running coach. Analyse these {len(workouts)} recent running workouts "
        f"and provide a comprehensive training review.\n",
        "## Running History (most recent first)",
    ]
    for i, w in enumerate(workouts[:20], 1):
        d = datetime.fromisoformat(w.date).strftime("%d %b %Y")
        line = f"\n### Run {i} — {d}"
        line += f"\n- {w.formatted_distance} in {w.formatted_duration} @ {w.formatted_pace}"
        if w.hr_avg:
            line += f"\n- Avg HR: {w.hr_avg} bpm"
            if w.hr_max:
                line += f" (max {w.hr_max} bpm)"
        if w.calories:
            line += f"\n- Calories: {w.calories:.0f} kcal"
        if w.elevation_gain_m:
            line += f"\n- Elevation: +{w.elevation_gain_m:.0f} m"
        lines.append(line)

    lines += [
        "\nPlease provide:",
        "**1. Overall Progress** — trends in distance, pace, and fitness",
        "**2. Training Load Assessment** — volume, intensity, over/under-training signs",
        "**3. Pacing Patterns** — consistency, problematic habits",
        "**4. Heart Rate Trends** — training zones, aerobic development",
        "**5. Strengths** — what's going well",
        "**6. Top 5 Improvement Areas** — prioritised, actionable recommendations",
        "**7. Suggested 2-Week Training Plan** — tailored to these patterns",
    ]
    return "\n".join(lines)


@app.post("/api/analyse")
async def analyse(req: AnalyseRequest):
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        raise HTTPException(500, "ANTHROPIC_API_KEY environment variable not set.")

    if req.mode == "single":
        prompt = _build_single_prompt(req.workouts, req.target_index)
    else:
        prompt = _build_trend_prompt(req.workouts)

    client = anthropic.Anthropic(api_key=api_key)

    stream = client.messages.stream(
        model="claude-opus-4-6",
        max_tokens=2048,
        thinking={"type": "adaptive"},
        messages=[{"role": "user", "content": prompt}],
    )

    with stream as s:
        full = s.get_final_message()

    text = next(
        (b.text for b in full.content if hasattr(b, "text")),
        "No analysis returned.",
    )
    return {"analysis": text}


# ── Dev server ────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
