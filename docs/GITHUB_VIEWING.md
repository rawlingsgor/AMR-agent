# Viewing the Vivli/ATLAS AMR EDA in GitHub

GitHub can display the analysis only after the generated report files are committed and pushed. The private raw Vivli CSV should not be committed.

## 1. Run the EDA locally

From the repository root in RStudio, run:

```r
source("R/rstudio_run_atlas_amr_eda.R")
```

Or from a terminal with R installed, run:

```bash
Rscript R/atlas_amr_eda.R ~/Desktop/atlas_vivli_2004_2024.csv reports
```

## 2. Review the generated files locally

The important outputs are:

- `reports/atlas_amr_eda_findings.md` — narrative findings and limitations.
- `reports/figures/*.png` — histograms, bar charts, pie chart, scatter plot, box plot, heat map, and trend plots.
- `reports/tables/*.csv` — quality checks, missingness profile, outlier review, and LMIC ESKAPE summaries.
- `data/processed/atlas_amr_cleaned.csv` — cleaned analysis dataset; commit this only if the challenge rules allow derived data to be stored in GitHub.

## 3. Add only shareable outputs to GitHub

The repository ignores generated outputs by default to prevent accidental upload of private challenge data. To publish the analysis artifacts, force-add the shareable report files only:

```bash
git add -f reports/atlas_amr_eda_findings.md reports/figures/*.png reports/tables/*.csv
```

Do not add the raw CSV:

```bash
git status --short data/raw
```

## 4. Commit and push

```bash
git commit -m "Publish Vivli ATLAS AMR EDA results"
git push
```

After pushing, open the GitHub repository in your browser:

- The markdown findings file will render directly on GitHub.
- PNG charts will display directly in `reports/figures/`.
- CSV summary tables will be browsable in `reports/tables/`.

## 5. Optional GitHub README gallery

If you want the charts to appear on the repository front page, add links like this to `README.md` after committing the generated PNG files:

```markdown
![Resistance-rate histogram](reports/figures/hist_resistance_rate.png)
![LMIC ESKAPE heat map](reports/figures/heatmap_lmic_eskape_antibiotic.png)
![LMIC ESKAPE trend](reports/figures/trend_lmic_eskape.png)
```

## Privacy warning

Before publishing results, confirm that the Vivli challenge terms allow derived tables and plots to be shared publicly or in the chosen GitHub repository. If the repository is public and the outputs contain small-cell country/pathogen/drug combinations, consider keeping it private or suppressing small cells before publishing.
