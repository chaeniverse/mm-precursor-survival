# mm-precursor-survival

Nationwide claims-based survival analysis of multiple myeloma diagnosed with, versus without, a prior precursor condition (MGUS or smoldering myeloma).

This repository accompanies the study *"Improved survival in multiple myeloma following prior detection of precursor conditions: a nationwide real-world study"* (Blood Cancer Journal, 2025). Using the Korean Health Insurance Review and Assessment Service (HIRA) claims database, three mutually exclusive cohorts were constructed — patients who progressed to multiple myeloma (MM) from a previously coded MGUS, patients who progressed from smoldering MM (SMM), and patients diagnosed with MM de novo — and their overall survival was compared after adjustment for age, sex, comorbidity burden, and frontline treatment intensity.

- **Paper:** [https://www.nature.com/articles/s41408-025-01395-6](https://www.nature.com/articles/s41408-025-01395-6) · DOI [10.1038/s41408-025-01395-6](https://doi.org/10.1038/s41408-025-01395-6) · PMID [41168167](https://pubmed.ncbi.nlm.nih.gov/41168167/)
- **Open access full text:** [PMC12575773](https://pmc.ncbi.nlm.nih.gov/articles/PMC12575773/)
- **Study identifier:** CAREMM-2307, Catholic REsearch Network for Multiple Myeloma (CARE-MM)
- **Status:** Published — *Blood Cancer Journal* **15**, 185 (30 October 2025)

> **Reproducibility.** The underlying HIRA claims data cannot be shared publicly and are only accessible inside the HIRA remote analysis environment (see [Data availability](#data-availability)). This repository therefore provides the full analytical pipeline — cohort construction, operational definitions, and the survival models — so that every reported number can be traced to the code that produced it.

## Overview

MGUS and SMM are asymptomatic precursors of MM, but whether detecting them before MM develops translates into a survival benefit has been difficult to answer outside of screening trials. This study addresses the question with a population-wide claims cohort in which precursor detection happened as part of routine care.

- **Data source:** Health Insurance Review and Assessment Service (HIRA) claims database, Republic of Korea — covering essentially the entire Korean population, including medical-aid beneficiaries.
- **Identification period:** 1 January 2009 – 30 November 2022 (claims from 2007–2008 used as a washout window).
- **Source populations:** newly diagnosed MGUS (n = 5,500) and newly diagnosed myeloma-coded disease, i.e. SMM or MM (n = 17,809).
- **Analysis cohorts:** MGUS to MM (n = 199) · SMM to MM (n = 447) · de novo MM (n = 15,067).
- **Primary outcome:** overall survival from the start of MM-directed treatment, with a 6-month landmark to guard against immortal-time bias.
- **Adjustment:** inverse probability of treatment weighting (IPTW) on age group, sex, Charlson Comorbidity Index, and frontline regimen intensity.

## Key results

| Cohort | n | Median follow-up (y) | Median OS (y) | Weighted HR vs. de novo MM |
|---|---|---|---|---|
| MGUS to MM | 199 | 4.0 (95% CI 3.4–5.4) | 7.9 | **0.53** (95% CI 0.39–0.71), *p* < 0.001 |
| SMM to MM | 447 | 5.0 (95% CI 4.6–5.6) | 5.5 | **0.83** (95% CI 0.70–0.98), *p* = 0.025 |
| De novo MM | 15,067 | 5.3 (95% CI 5.2–5.4) | 4.4 | reference |

- **Progression from precursor states.** The 10-year cumulative incidence of progression to MM was 7.0% (95% CI 5.9–8.2) from MGUS and 36.2% (95% CI 33.4–39.0) from SMM; median times to progression were 3.7 and 2.0 years, respectively.
- **Sensitivity to unmeasured confounding.** The E-value for the MGUS-to-MM estimate was 3.18 (1.96 for the upper confidence limit), i.e. only unmeasured confounding with a risk ratio ≥ 3.18 could explain away the observed benefit.
- **Interpretation.** The findings do not support universal population screening, but they do support structured monitoring of individuals already known to have MGUS or SMM, particularly those at higher risk of progression.

## Repository structure

```
mm-precursor-survival
 ├── Mgus to MM cohort.sas            # MGUS cohort + MGUS-to-MM progression cohort
 ├── sMM to MM cohort.sas             # SMM cohort + SMM-to-MM progression cohort, CRAB, CCI
 ├── De novo MM cohort.sas            # de novo MM cohort: CCI block + regimen terms
 ├── Defined Dataset.sas              # analysis-dataset assembly (T200/T300/T530 joins, last-visit & death dates)
 ├── MM medication code.sas           # frontline regimen classification from HIRA drug codes
 ├── Revision.sas                     # CRAB ascertainment windows (+-3 / 6 / 12 months) for the revision
 ├── Manuscript.R                     # main analysis: Table 1, CCI, IPTW, landmark Cox, KM, cumulative incidence
 ├── Revision.R                       # revision analyses: CRAB patterns, +-3-month reclassification, bisphosphonate exclusion
 ├── 250318_CHcode.R                  # dated working versions of the analysis (v4 / v5 datasets)
 ├── 250415_CHcode.R                  #   "  — adds explicit landmark vs. follow-up analysis blocks
 ├── Confidence Interval of Cuminc.R  # log-log confidence limits for 10-year cumulative incidence
 └── Distinct DIV_CD.R                # utility: de-duplicate drug ingredient codes for the data-request file
```

## Analysis pipeline

The pipeline runs **SAS first, then R**. SAS extracts and shapes the claims tables inside the HIRA environment and writes `sas7bdat` analysis files; R reads those files with `haven::read_sas()` and produces every table and figure.

```
HIRA claims tables (T200 / T300 / T530)
        │
        ├─ Mgus to MM cohort.sas ─┐
        ├─ sMM to MM cohort.sas   ├─ mgus_to_symmm_v*.sas7bdat
        ├─ De novo MM cohort.sas  │  smm_to_symmm_v*.sas7bdat
        ├─ Defined Dataset.sas    │  denovo_symMM_v*.sas7bdat
        ├─ MM medication code.sas │  to_mm_crab_mm.sas7bdat
        └─ Revision.sas ──────────┘
        │
        └─ Manuscript.R / Revision.R  →  Table 1, survival curves, cumulative-incidence plots
```

HIRA table roles: **T200** = claim-level diagnoses (`MAIN_SICK`, `SUB_SICK`, visit dates, age, outcome code); **T300** / **T530** = procedure and drug line items (`DIV_CD`).

## Operational definitions

All definitions are implemented in the SAS scripts; the notes below point to where each one lives.

**MGUS** (`Mgus to MM cohort.sas`) — ICD-10 **D47.2** recorded on **two or more** separate claims; the earliest D47.2 claim is the index date. Excluded: index date in 2007–2008 (washout), age < 19 at index, and any C90 code before or within 6 months after the MGUS index date.

**Myeloma** (`sMM to MM cohort.sas`, `De novo MM cohort.sas`) — ICD-10 **C90** on two or more claims **together with the V193 special-copayment registration code** for cancer, which in Korea accompanies a confirmed malignancy. The date of the first MM-directed drug claim defines symptomatic MM (`first_mm_date`) and is the index date for survival analysis; patients whose only myeloma treatment fell outside the study drug list were excluded.

**Cohort assignment** — *MGUS to MM*: MGUS index, then C90 and MM-directed treatment during follow-up. *SMM to MM*: C90 + V193 with no preceding D47.2 and no MM-directed therapy at diagnosis, later starting treatment. *De novo MM*: C90 + V193 with treatment at diagnosis and no preceding precursor code.

**CRAB features** (`Revision.sas`) — ascertained in ±3-, 6-, and 12-month windows around `first_mm_date` from both diagnosis and procedure codes:

| Feature | Diagnosis codes (T200 `MAIN_SICK`) | Drug / procedure codes (T300, T530 `DIV_CD`) |
|---|---|---|
| **C** Hypercalcemia | E83.52 | `420731BIJ`, `420732BIJ`, `480330BIJ`, `207930BIJ` (bisphosphonate / anti-hypercalcemic injections) |
| **R** Renal insufficiency | N18.3, N18.4, N18.5 | `500330`–`500343BIJ` injections plus `459701AGN`, `459701ATD`, `459702ACH` |
| **A** Anemia | D63.0 | the same `500330`–`500343BIJ` injections, plus transfusion codes `X1001/X1002`, `X2021/X2022`, `X2031/X2032`, `X2091/X2092`, `X2111/X2112`, `X2131/X2132`, `X2512`, `X2515`, `X6001/X6002/X6006` |
| **B** Bone lesions | M48.4, M48.5, M80.88, S22.0/S22.1, S32.0/S32.7, S72.0/S72.1, T08 | the hypercalcemia bisphosphonate codes above |

A feature counts as present if **either** the diagnosis code **or** a supporting drug/procedure code appears in the window. Because the bisphosphonate codes serve both the **C** and **B** definitions, the revision also reports a bone-lesion variant with those codes excluded (`# [25-07-31] CRAB: BisphoEx` in `Revision.R`).

**Charlson Comorbidity Index** (`De novo MM cohort.sas`, and the *Score 계산* block in the R scripts) — 14 conditions ascertained from claims in the **12 months before** the index date, weighted 1 (MI, CHF, PVD, cerebrovascular disease, dementia, COPD, rheumatic disease, peptic ulcer, liver disease, diabetes), 2 (hemiplegia, renal disease, prior cancer), or 6 (AIDS).

**Frontline regimen intensity** (`MM medication code.sas`, collapsed in `Manuscript.R`) — melphalan / bortezomib / thalidomide / lenalidomide claims within the treatment window are combined into:

- **Doublet** — MP (melphalan-based), VD, thalidomide alone, or lenalidomide alone
- **Low-intensity triplet** — VMP (melphalan + bortezomib, ± IMiD)
- **High-intensity triplet** — VTD (bortezomib + thalidomide, ± lenalidomide)
- **Other** — anything outside the above

## Statistical methods

- **Landmark design.** Survival is measured from `first_mm_date`; patients with less than 6 months of follow-up are excluded (`death_year >= 0.5`) so that the precursor-detected groups are not advantaged by immortal time. The 0–6-month period is analysed separately in the follow-up blocks of `250415_CHcode.R` and `Manuscript.R`.
- **Confounding adjustment.** IPTW with stabilized weights estimated from a multinomial model of cohort membership on `ageg4 + SEX_TP_CD + CCI_score + Doublet + Low_intensity_triplet + High_intensity_triplet`; balance is checked with `cobalt` (the `###### balance check` block).
- **Survival models.** Weighted `survival::coxph()` with robust standard errors, de novo MM as the reference; weighted `survfit()` for adjusted Kaplan–Meier curves, drawn with `survminer::ggsurvplot()`.
- **Follow-up duration.** Reverse Kaplan–Meier (event indicator inverted) rather than naive median follow-up.
- **Progression from precursor states.** Competing-risk cumulative incidence with `cmprsk::cuminc()` (death without progression as the competing event), indexed from the first D47.2 / C90 date; curves are drawn from `mstate::crprep()` censoring weights. Confidence limits at 10 years and at the median use the log-log transform, coded separately in `Confidence Interval of Cuminc.R`.
- **Sensitivity analyses** (`Revision.R`, `Revision.sas`) — reclassifying SMM patients treated within ±3 months of diagnosis as de novo, widening that boundary beyond 3 months, varying the CRAB ascertainment window (3 vs. 6 vs. 12 months), and excluding bisphosphonate-only bone signals.

## Environment

Analyses were run in the HIRA remote research environment: **SAS 9.4** for cohort construction and **R** for statistical analysis. The scripts expect the SAS library and R working directory to be the same HIRA user folder (`libname aa '/vol/userdata14/sta_room462'` and the matching `setwd()` at the top of each R script) — change both to a local path to run against your own extract.

R packages used across the scripts:

```r
install.packages(c(
  "survival", "survminer", "cmprsk", "mstate", "MatchIt", "WeightIt", "cobalt",
  "ebal", "VGAM", "nnet", "survey", "tableone", "moonBook", "data.table",
  "dplyr", "tidyr", "magrittr", "lubridate", "haven", "sas7bdat", "readxl",
  "writexl", "ggplot2", "ggpubr", "ggsci", "gridExtra", "scales", "officer",
  "knitr"
))
```

**Notes when re-running**

- The weighting helper `get_sw()` is sourced from `R_spj/MGUS_MM_function.R`, an environment-local file that is **not** part of this repository; the `source()` calls appear commented out in the scripts. Substitute your own stabilized-weight function with the same signature (`get_sw(formula, data)` returning a data frame with a `weight` column), or use `WeightIt::weightit(..., method = "ps", estimand = "ATE", stabilize = TRUE)`.
- `Surv_Prov()`, the helper for survival probability at a fixed time point, **is** defined inline in `Manuscript.R`, `250318_CHcode.R`, and `250415_CHcode.R`.
- The `.sas` files carry Korean comments in **CP949** encoding (the R files are UTF-8). Read them with `iconv -f CP949 -t UTF-8 <file>` if the comments appear garbled.
- `Manuscript.R` is the script behind the published figures and tables; `250318_CHcode.R` and `250415_CHcode.R` are earlier dated snapshots against intermediate dataset versions (`v4`, `v5`) and are kept for provenance.

## Data availability

The data used in this study are claims records held by the Korean Health Insurance Review and Assessment Service and cannot be shared publicly by the authors. Researchers may apply for access through the HIRA Healthcare Bigdata Hub, subject to HIRA review and approval; analyses are performed inside HIRA's remote environment. The study was approved by the Institutional Review Board of Seoul St. Mary's Hospital, Seoul, Republic of Korea.

## Citation

> Choi S, Park S-S, Lee CH, Jung S, Koshiaris C, Ramasamy K, Han S, Min C-K. Improved survival in multiple myeloma following prior detection of precursor conditions: a nationwide real-world study. *Blood Cancer J.* 2025;15(1):185. doi:10.1038/s41408-025-01395-6

```bibtex
@article{choi2025mmprecursor,
  title   = {Improved survival in multiple myeloma following prior detection of
             precursor conditions: a nationwide real-world study},
  author  = {Choi, Suein and Park, Sung-Soo and Lee, Chae Hyeon and Jung, Seungpil
             and Koshiaris, Constantinos and Ramasamy, Karthik and Han, Seunghoon
             and Min, Chang-Ki},
  journal = {Blood Cancer Journal},
  volume  = {15},
  number  = {1},
  pages   = {185},
  year    = {2025},
  doi     = {10.1038/s41408-025-01395-6}
}
```
