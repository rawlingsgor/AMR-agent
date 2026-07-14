# AMR-agent

Multi-agent AI framework that reasons over antimicrobial-resistance (AMR) surveillance data, integrates cross-domain knowledge, and adapts to local contexts.

## Vivli Data Challenge 2026: ATLAS AMR EDA

This repository now includes a reproducible R workflow for an antimicrobial-resistance-specific exploratory data analysis (EDA) of the Vivli/ATLAS CSV export. The workflow follows a standard EDA sequence: problem/data understanding, import and inspection, missing-data review, transformation, univariate analysis, bivariate analysis, multivariate analysis, outlier review, insight communication, and limitation reporting.

### Data placement

The challenge dataset is not committed to git. Place it at:

```text
data/raw/atlas_vivli_2004_2024.csv
```

or pass another path to the R script:

```bash
Rscript R/atlas_amr_eda.R /path/to/atlas_vivli_2004_2024.csv reports
```


### RStudio paste-and-run helper

If your CSV is on your Desktop and you want to reproduce the outputs interactively in RStudio, open the project root and run:

```r
source("R/rstudio_run_atlas_amr_eda.R")
```

The helper locates `~/Desktop/atlas_vivli_2004_2024.csv`, runs the EDA, loads key tables into the RStudio environment, opens the findings markdown file, and steps through every generated PNG graph in the Plots pane.

### Install R dependencies

```bash
Rscript r_dependencies.R
```

### Run the EDA

```bash
Rscript R/atlas_amr_eda.R data/raw/atlas_vivli_2004_2024.csv reports
```

### Viewing results in GitHub

Generated reports are ignored by default so the private Vivli CSV is not accidentally published. After running the EDA locally, follow `docs/GITHUB_VIEWING.md` to force-add only shareable markdown, PNG, and CSV report artifacts so GitHub can render the findings and charts.

### Outputs

The script writes:

- `data/processed/atlas_amr_cleaned.csv` — standardized analysis dataset with explicit quality flags.
- `reports/tables/data_quality_summary.csv` — row counts, duplicate counts, LMIC and ESKAPE coverage.
- `reports/tables/missingness_profile.csv` — missing-value counts and percentages for all standardized fields.
- `reports/tables/iqr_outlier_records_review_not_removed.csv` — statistically extreme records that need domain review rather than automatic deletion.
- `reports/tables/top_lmic_eskape.csv` — country/pathogen/antibiotic summaries emphasizing LMIC ESKAPE findings.
- `reports/figures/` — histogram, bar chart, pie chart, scatter plot, box plot, heat map, and resistance trend visualizations.
- `reports/atlas_amr_eda_findings.md` — auto-generated narrative findings, safeguards, and limitations.

### Cleaning principles

- Required identifiers are year, country, and pathogen; missing core identifiers are flagged rather than imputed.
- Impossible rates, non-positive denominators, and resistant counts exceeding tested counts are excluded from analysis-ready summaries.
- IQR outliers are exported for review but are not automatically removed, because extreme AMR rates can represent real local resistance signals.
- LMIC and ESKAPE classifications are stored as auditable configuration files under `config/`.

## Agent roadmap

The next agent-building stage should consume the cleaned outputs and expose:

1. dataset-quality diagnostics,
2. LMIC ESKAPE pathogen-drug-country drilldowns,
3. trend explanations with explicit surveillance-bias warnings,
4. reproducible plot/table provenance for every answer.
