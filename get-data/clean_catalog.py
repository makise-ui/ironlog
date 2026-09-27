#!/usr/bin/env python3
"""
IronLog Catalog AI Cleanup Harness
-----------------------------------
Uses Agnes AI (agnes-3.0-flash) to clean, normalize, and enrich exercise data
to ensure 100% compatibility with IronLog's Drift SQLite schema.

Features:
- Pure Python standard library (no pip install needed; runs anywhere, including Android Termux)
- Multi-threaded parallel processing for fast execution
- Automatic checkpointing and resume support (never re-does completed exercises)
- Schema validation and fallback normalization
"""

import os
import sys
import json
import time
import re
import argparse
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

API_URL = "https://apihub.agnes-ai.com/v1/chat/completions"
DEFAULT_API_KEY = "sk-2ppD2OEa8km8UnFQvS9oMyHEJnr4arg12aNzqyBOTVGPW0jt"
DEFAULT_MODEL = "agnes-3.0-flash"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
INPUT_FILE = os.path.join(SCRIPT_DIR, "raw_exercises.json")
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "cleaned_exercises.json")
APP_TARGET_FILE = os.path.join(SCRIPT_DIR, "..", "assets", "exercises", "opengym_exercises.json")

VALID_MUSCLE_GROUPS = {
    "chest", "back", "shoulders", "biceps", "triceps",
    "legs", "glutes", "core", "forearms", "cardio"
}

MUSCLE_GROUP_ALIASES = {
    "abs": "core", "abdominals": "core", "waist": "core", "obliques": "core",
    "quadriceps": "legs", "quads": "legs", "hamstrings": "legs", "calves": "legs", "thighs": "legs",
    "lats": "back", "traps": "back", "trapezius": "back", "upper back": "back", "lower back": "back",
    "middle back": "back", "spine": "back", "erector spinae": "back",
    "pectorals": "chest", "pecs": "chest",
    "deltoids": "shoulders", "delts": "shoulders", "rotator cuff": "shoulders", "lateral delts": "shoulders",
    "arms": "biceps", "forearm": "forearms", "grip": "forearms",
    "gluteus": "glutes", "buttocks": "glutes", "hips": "glutes",
    "aerobic": "cardio", "endurance": "cardio", "conditioning": "cardio"
}

VALID_EQUIPMENTS = {
    "barbell", "dumbbell", "machine", "cable", "bodyweight", "assisted", "other"
}

EQUIPMENT_ALIASES = {
    "body weight": "bodyweight", "floor": "bodyweight", "none": "bodyweight", "mat": "bodyweight",
    "smith machine": "machine", "leverage machine": "machine", "selectorized": "machine",
    "plate loaded": "machine", "sled machine": "machine", "hack squat machine": "machine",
    "ez barbell": "barbell", "olympic barbell": "barbell", "trap bar": "barbell", "hex bar": "barbell",
    "kettlebell": "other", "bands": "other", "resistance band": "other", "medicine ball": "other"
}

SYSTEM_PROMPT = """You are an elite strength & conditioning coach and sports biomechanics database expert.
Your job is to normalize and calibrate an exercise into a strictly typed JSON object for the IronLog gym app.

STRICT SCHEMA RULES:
1. "muscleGroupId": Must be EXACTLY one of: ["chest", "back", "shoulders", "biceps", "triceps", "legs", "glutes", "core", "forearms", "cardio"].
2. "secondaryGroups": Array of secondary anatomical muscle strings (e.g. ["triceps", "shoulders"]).
3. "equipment": Must be EXACTLY one of: ["barbell", "dumbbell", "machine", "cable", "bodyweight", "assisted", "other"].
4. "loadMode": Must be EXACTLY one of:
   - "per_hand": If dumbbells or unilateral separate weights (weight logged per hand, volume is 2x).
   - "bodyweight": For pull-ups, push-ups, dips, crunches, air squats.
   - "assisted": For machine-assisted pull-ups/dips (offset weight).
   - "total": For standard barbells, machines, cables.
5. "isUnilateral": true if single-arm, single-leg, or alternating. false otherwise.
6. "weightStep": 5.0 for machine pin-stacks, 2.5 for barbells/dumbbells/cables, 0.0 for pure bodyweight.
7. "repMin" and "repMax": Realistic gym target range (e.g. 5-8 for heavy compounds, 8-12 for standard, 10-15 for isolations/cables, 12-20 for core/calves).
8. "restSeconds": 120-180 for heavy compounds, 90 for standard, 60 for isolations/arms, 45 for core/abs/cardio.
9. "trackingType": "duration" for isometric holds (planks, dead hangs, wall sits), "bodyweightReps" for calisthenics, "cardioTime" for cardio, "weightAndReps" for weights.
10. "instructions": Array of 3-5 concise, practical, step-by-step form cues.

CRITICAL: Return ONLY valid JSON with no markdown wrapping, no introductory text, and no backticks.
"""

def normalize_exercise(ex_dict, raw_item):
    """Fallback validation to guarantee 100% compliance with IronLog schema."""
    name = (ex_dict.get("name") or raw_item.get("name") or "").strip()
    ex_id = (raw_item.get("id") or ex_dict.get("id") or f"og_{int(time.time()*1000)}").strip()

    # Muscle group
    mg = str(ex_dict.get("muscleGroupId") or raw_item.get("muscleGroupId") or "legs").lower().strip()
    mg = MUSCLE_GROUP_ALIASES.get(mg, mg)
    if mg not in VALID_MUSCLE_GROUPS:
        mg = "legs"

    # Secondary groups
    sec = ex_dict.get("secondaryGroups") or raw_item.get("secondaryGroups") or []
    if isinstance(sec, str):
        sec = [s.strip() for s in sec.split(",") if s.strip()]
    elif not isinstance(sec, list):
        sec = []
    sec = [str(s).strip() for s in sec if str(s).strip()]

    # Equipment
    eq = str(ex_dict.get("equipment") or raw_item.get("equipment") or "barbell").lower().strip()
    eq = EQUIPMENT_ALIASES.get(eq, eq)
    if eq not in VALID_EQUIPMENTS:
        eq = "other"

    # Load mode
    lm = str(ex_dict.get("loadMode") or "").lower().strip()
    if lm not in {"total", "per_hand", "bodyweight", "assisted"}:
        if eq == "dumbbell":
            lm = "per_hand"
        elif eq == "bodyweight":
            lm = "bodyweight"
        elif eq == "assisted":
            lm = "assisted"
        else:
            lm = "total"

    # Unilateral
    lower_name = name.lower()
    is_uni = bool(ex_dict.get("isUnilateral", False))
    if any(k in lower_name for k in ["single-arm", "single arm", "one-arm", "one arm", "single-leg", "single leg", "one-leg", "one leg", "alternating", "unilateral"]):
        is_uni = True

    # Weight step
    step = ex_dict.get("weightStep")
    try:
        step = float(step)
    except (ValueError, TypeError):
        step = 5.0 if eq == "machine" else (0.0 if eq == "bodyweight" else 2.5)

    # Rep ranges
    try:
        rep_min = int(ex_dict.get("repMin", 8))
        rep_max = int(ex_dict.get("repMax", 12))
        if rep_min <= 0: rep_min = 8
        if rep_max < rep_min: rep_max = rep_min + 4
    except (ValueError, TypeError):
        rep_min, rep_max = 8, 12

    # Rest seconds
    try:
        rest = int(ex_dict.get("restSeconds", 90))
        if rest <= 0: rest = 90
    except (ValueError, TypeError):
        rest = 90

    # Tracking type
    tt = ex_dict.get("trackingType")
    if tt not in {"weightAndReps", "bodyweightReps", "duration", "cardioTime"}:
        if any(h in lower_name for h in ["plank", "dead hang", "hang", "wall sit", "l-sit", "hold"]):
            tt = "duration"
        elif eq == "bodyweight" and mg in {"core", "cardio"}:
            tt = "bodyweightReps"
        elif mg == "cardio":
            tt = "cardioTime"
        else:
            tt = "weightAndReps"

    # Instructions
    instructions = ex_dict.get("instructions") or raw_item.get("instructions") or []
    if isinstance(instructions, str):
        instructions = [i.strip() for i in instructions.split("\n") if i.strip()]
    elif not isinstance(instructions, list):
        instructions = []

    return {
        "id": ex_id,
        "name": name,
        "muscleGroupId": mg,
        "secondaryGroups": sec,
        "equipment": eq,
        "loadMode": lm,
        "isUnilateral": is_uni,
        "weightStep": step,
        "repMin": rep_min,
        "repMax": rep_max,
        "restSeconds": rest,
        "trackingType": tt,
        "instructions": instructions
    }

def clean_exercise_with_ai(raw_item, api_key, model=DEFAULT_MODEL, retries=3):
    """Sends exercise to Agnes AI and returns cleaned JSON."""
    user_payload = {
        "id": raw_item.get("id"),
        "name": raw_item.get("name"),
        "muscleGroupId": raw_item.get("muscleGroupId"),
        "equipment": raw_item.get("equipment"),
        "secondaryGroups": raw_item.get("secondaryGroups", []),
        "instructions": raw_item.get("instructions", [])
    }

    req_data = {
        "model": model,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"Enrich and clean this exercise data into strict JSON:\\n{json.dumps(user_payload)}"
            }
        ],
        "temperature": 0.2
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }

    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(API_URL, data=json.dumps(req_data).encode("utf-8"), headers=headers, method="POST")
            with urllib.request.urlopen(req, timeout=15) as resp:
                result = json.loads(resp.read().decode("utf-8"))
                content = result["choices"][0]["message"]["content"].strip()

                # Extract JSON if enclosed in markdown code fences
                match = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", content)
                if match:
                    content = match.group(1).strip()

                parsed = json.loads(content)
                return normalize_exercise(parsed, raw_item)
        except Exception as e:
            if attempt < retries:
                time.sleep(1.0 * attempt)
            else:
                # Fallback to local heuristic normalization on failure
                return normalize_exercise({}, raw_item)

def main():
    parser = argparse.ArgumentParser(description="IronLog Exercise Catalog AI Cleanup")
    parser.add_argument("--api-key", default=DEFAULT_API_KEY, help="Agnes AI API Key")
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model name")
    parser.add_argument("--workers", type=int, default=6, help="Number of concurrent worker threads")
    parser.add_argument("--limit", type=int, default=None, help="Limit number of exercises to process")
    parser.add_argument("--apply", action="store_true", help="Apply cleaned exercises directly to app assets")
    args = parser.parse_args()

    if not os.path.exists(INPUT_FILE):
        print(f"[!] Error: Input file not found: {INPUT_FILE}")
        sys.exit(1)

    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        raw_exercises = json.load(f)

    if args.limit:
        raw_exercises = raw_exercises[:args.limit]

    print(f"[*] Loaded {len(raw_exercises)} exercises from {INPUT_FILE}")

    # Load existing checkpoint if available
    cleaned_dict = {}
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                saved = json.load(f)
                cleaned_dict = {item["id"]: item for item in saved if "id" in item}
            print(f"[*] Found checkpoint with {len(cleaned_dict)} already cleaned exercises. Resuming...")
        except Exception:
            pass

    # Filter exercises still needing processing
    pending = [ex for ex in raw_exercises if ex.get("id") not in cleaned_dict]
    print(f"[*] Exercises to process: {len(pending)} (using {args.workers} concurrent workers)")

    if not pending:
        print("[+] All exercises already processed!")
    else:
        completed = len(cleaned_dict)
        total = len(raw_exercises)
        start_time = time.time()

        with ThreadPoolExecutor(max_workers=args.workers) as executor:
            future_to_id = {
                executor.submit(clean_exercise_with_ai, ex, args.api_key, args.model): ex["id"]
                for ex in pending
            }

            for future in as_completed(future_to_id):
                ex_id = future_to_id[future]
                try:
                    result = future.result()
                    cleaned_dict[result["id"]] = result
                    completed += 1

                    elapsed = time.time() - start_time
                    rate = (completed - len(raw_exercises) + len(pending)) / max(elapsed, 0.001)
                    percent = (completed / total) * 100

                    print(f"[{completed}/{total}] ({percent:.1f}%) Cleaned: {result['name']} (rest: {result['restSeconds']}s, {result['repMin']}-{result['repMax']} reps) - {rate:.1f} ex/s")

                    # Periodically save checkpoint every 10 exercises
                    if completed % 10 == 0:
                        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
                            json.dump(list(cleaned_dict.values()), f, indent=2)

                except Exception as err:
                    print(f"[!] Error on {ex_id}: {err}")

        # Final save
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(list(cleaned_dict.values()), f, indent=2)

    print(f"\n[+] Successfully saved {len(cleaned_dict)} exercises to {OUTPUT_FILE}")

    if args.apply:
        print(f"[*] Applying cleaned catalog to app asset: {APP_TARGET_FILE}")
        with open(APP_TARGET_FILE, "w", encoding="utf-8") as f:
            json.dump(list(cleaned_dict.values()), f, indent=2)
        print("[+] Applied successfully to IronLog app assets!")

if __name__ == "__main__":
    main()
