# IronLog Catalog AI Cleanup Harness

This harness processes, enriches, and formats all 1,300+ openGym exercises using Agnes AI (`agnes-3.0-flash`) so that every exercise is 100% compliant with IronLog's Drift SQLite database schema.

---

## What It Enriches for Every Movement:
* **`muscleGroupId`:** Strictly mapped to IronLog's 10 verified anatomy groups (`chest`, `back`, `shoulders`, `biceps`, `triceps`, `legs`, `glutes`, `core`, `forearms`, `cardio`).
* **`secondaryGroups`:** Anatomical synergist muscles.
* **`equipment`:** `barbell`, `dumbbell`, `machine`, `cable`, `bodyweight`, `assisted`, or `other`.
* **`loadMode`:** `per_hand` for dumbbells, `bodyweight` for calisthenics, `assisted` for assisted machines, `total` for barbells/cables.
* **`weightStep`:** 5.0 kg for machines, 2.5 kg for free weights/cables, 0.0 kg for bodyweight.
* **`repMin` & `repMax`:** Calibrated for heavy compounds (5–8), standard (8–12), isolations (10–15), or core (12–20).
* **`restSeconds`:** 120s for compounds, 90s for presses/rows, 60s for arms/accessories, 45s for core/cardio.
* **`trackingType`:** `duration` for timed holds (planks, wall sits), `bodyweightReps` for calisthenics, `cardioTime` for cardio, `weightAndReps` for lifting.
* **`instructions`:** 3–5 step-by-step form execution cues.

---

## Files in This Folder:
* [`clean_catalog.py`](file:///home/kurisu/gym-app/get-data/clean_catalog.py): The pure Python multi-threaded harness (no pip dependencies required).
* [`raw_exercises.json`](file:///home/kurisu/gym-app/get-data/raw_exercises.json): The input catalog of 1,324 exercises.
* [`run.sh`](file:///home/kurisu/gym-app/get-data/run.sh): Ready-to-run shell script.

---

## How to Run:

### 1. Run Everything (Default 6 Workers):
```bash
python3 clean_catalog.py
```

### 2. Run Faster (10–12 Concurrent Workers):
```bash
python3 clean_catalog.py --workers 10
```

### 3. Run and Automatically Apply to App Assets:
```bash
python3 clean_catalog.py --workers 10 --apply
```
*(This automatically updates `assets/exercises/opengym_exercises.json` once completed!)*

### 4. Test a Small Batch First (e.g. 5 exercises):
```bash
python3 clean_catalog.py --limit 5
```

---

## Running on Mobile (Termux / Android):
Because this script uses **standard Python library modules only (`urllib.request`, `json`, `concurrent.futures`)**, no `pip install` is needed!

1. Open Termux on your phone.
2. Navigate to this folder:
   ```bash
   cd gym-app/get-data
   ```
3. Run:
   ```bash
   python3 clean_catalog.py --workers 8 --apply
   ```
4. **Pause & Resume Anytime:** If you close the terminal or phone screen, just run the command again. It detects existing cleaned entries and picks up right where it left off without duplicating work.
