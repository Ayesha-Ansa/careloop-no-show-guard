# CareLoop Clinics — No-Show Guard

**Public repository:** https://github.com/Ayesha-Ansa/careloop-no-show-guard

From raw clinic bookings to SQL analysis, no-show risk prediction and AI-assisted follow-up note review.

## Business question

**Which appointments are most likely to be missed, why do patients miss them, and what should CareLoop do first?**

CareLoop Clinics operates eight outpatient clinics. This project builds a connected workflow to clean appointment data, identify no-show patterns, predict appointment risk and structure a small sample of follow-up notes.

## Project findings — one result from each part

- **Part 1 — Data preparation:** Cleaned 1,020 raw booking rows to 990 usable appointments across 8 clinics; 218 appointments were no-shows (22.0%).
- **Part 2 — SQL analysis:** Gomti Nagar Care Point had the highest all-clinic no-show rate at 33.3% (30 of 90 appointments); the 31+ lead-day band had a 60.5% rate (26 of 43).
- **Part 3 — Machine learning:** Logistic Regression was selected with training cross-validation ROC-AUC 0.774; at threshold 0.35 it flagged 49 of 198 test appointments and achieved test ROC-AUC 0.789.
- **Part 4 — Generative AI:** Of the first 10 follow-up notes, 8 received valid structured classifications, 1 blank note was skipped and 1 response was invalid after a Gemini 503 service error.

## Business recommendation

CareLoop should use the Logistic Regression risk scores to prioritise evening-before follow-up calls, while using clinic and lead-time analysis to focus operational attention. Across 990 cleaned appointments, 218 were no-shows (22.0%). The highest all-clinic rate was 33.3% at Gomti Nagar Care Point, although its sample contained only 90 appointments; the 31+ lead-day group had a 60.5% no-show rate (26 of 43). The selected model uses a 0.35 threshold and flagged 49 of 198 held-out test appointments, with test recall of 0.571 and ROC-AUC of 0.789. The front desk should apply this risk list according to its actual evening calling capacity and the cost of an unused appointment slot. The ten-note GenAI sample is useful for illustrating possible follow-up actions, but it is too small to establish clinic-wide reason frequencies.

## SQL findings

### No-show rate by clinic

For clinics with at least 95 appointments, the highest rate was Hadapsar Care Centre (Pune): 39 no-shows out of 143 appointments (27.3%). Malviya Nagar Clinic (Jaipur) recorded 38 of 142 (26.8%). When the HAVING filter was removed, Gomti Nagar Care Point (Lucknow) was highest at 33.3%, based on 90 appointments.

### Booking lead time

| Lead-time band | Appointments | No-shows | No-show rate |
|---|---:|---:|---:|
| 1–7 days | 390 | 63 | 16.2% |
| 8–14 days | 304 | 53 | 17.4% |
| 15–30 days | 253 | 76 | 30.0% |
| 31+ days | 43 | 26 | 60.5% |

### Monthly trend

The monthly no-show rate was 24.8% in January 2025 (157 appointments) and 21.2% in June 2025 (165 appointments). The month-to-month percentage-point changes are calculated in the SQL notebook/script using LAG.

The overall no-show rate used for city-level clinic comparisons was 22.02%.

## Machine learning

The target is `no_show`. Features include age, distance, fee, lead days, prior no-shows, reminder status, booking channel and visit type. Identifiers, dates, clinic ID, gender and status are excluded.

Logistic Regression was selected using the highest mean five-fold cross-validated ROC-AUC on the training set:

| Model | Training CV ROC-AUC |
|---|---:|
| Logistic Regression (pipeline) | 0.774 |
| Tuned Random Forest | 0.767 |
| Random Forest | 0.747 |
| Decision Tree (depth 3) | 0.678 |

The threshold was selected from out-of-fold training probabilities. Threshold 0.35 had F1 0.489 and recall 0.467, compared with F1 0.347 and recall 0.249 at threshold 0.50.

Final held-out test results at threshold 0.35:

| Metric | Result |
|---|---:|
| Precision | 0.571 |
| Recall | 0.571 |
| ROC-AUC | 0.789 |
| Appointments flagged | 49 of 198 |

The test set was reserved for final reporting; model and threshold selection used training cross-validation and out-of-fold predictions.

## Generative AI follow-up note analysis

Gemini returns JSON with `root_cause`, `confidence`, `summary` and `recommended_action`. Pydantic validates the fields, and the allowed root-cause list is checked separately.

Final `notes_analysed.csv` status:
- 8 valid non-blank note responses.
- 1 blank note (N004), skipped without an API call and recorded with the required default values.
- 1 invalid response (N001), retained as invalid after a temporary Gemini 503 error; its unavailable fields remain blank.

The merged ten-note sample contains 5 appointments with `reminder_sent = No` and 5 with `reminder_sent = Yes`. N007 was classified as `forgot_or_no_reminder` and its appointment had no reminder. N001 remains invalid in the final batch output and has not been manually repaired. The V2 CRAFT prompt returned allowed categories for N007 and N009; the V1 simple prompt returned an out-of-list category for N009, while the N007 V1 request encountered a 503 error.

## Limitations

1. **Small note sample:** Only the first 10 follow-up notes were analysed. This is an illustration and cannot establish the real distribution of no-show reasons across all clinics; one note also had an unsuccessful API response.
2. **Cleaning before splitting:** The medians, quartiles and outlier fences were calculated using all 990 rows before the train/test split, so test rows indirectly influenced the cleaning statistics.
3. **Random split design:** The split was random rather than past-to-future, and the same patient may appear in both training and test data. A production evaluation should use time-based and patient-aware validation.

## Repository contents

```text
careloop-no-show-guard/
├── README.md
├── 01_ingest_clean.ipynb
├── rejected_rows.json
├── appointments_clean.csv
├── clinics_enriched.csv
├── load_data.sql
├── 02_queries.sql
├── 03_model.ipynb
├── test_risk_scores.csv
├── 04_genai.ipynb
├── notes_analysed.csv
├── notes_merged.csv
└── data/
    ├── appointments.csv
    ├── clinics.csv
    └── followup_notes.csv
```

## Reproducing the project

1. Open the notebooks in Google Colab.
2. Run `01_ingest_clean.ipynb` from the repository root. Its original input CSVs are read from `data/`; generated hand-off files are saved in the repository root.
3. Run the SQL setup and analysis in MySQL 8 using `load_data.sql` and `02_queries.sql`.
4. Run `03_model.ipynb` using `appointments_clean.csv`.
5. Run `04_genai.ipynb` using `data/followup_notes.csv`. Enter the Gemini API key at runtime when prompted; the key is not stored in this repository.

Main tools: Python, pandas, NumPy, requests, MySQL 8, scikit-learn, Google Gemini API and Pydantic.

## Data and security

The three original assignment CSV files are kept unchanged in `data/`. Do not commit API keys, credentials or private configuration files. The GenAI notebook requests the key at runtime using `getpass`.
