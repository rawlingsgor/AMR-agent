# Paste this entire script into RStudio and run it from the AMR-agent project root.
# It executes the reproducible Vivli/ATLAS AMR EDA pipeline, then opens the
# generated findings, tables, and graphs for local review.

# 1) Install/load packages used by the pipeline and by this RStudio viewer.
required_packages <- c(
  "tidyverse", "janitor", "readr", "scales", "png", "gridExtra"
)
new_packages <- required_packages[!(required_packages %in% rownames(installed.packages()))]
if (length(new_packages) > 0) {
  install.packages(new_packages, repos = "https://cloud.r-project.org/")
}

suppressPackageStartupMessages({
  library(tidyverse)
  library(readr)
  library(png)
  library(grid)
  library(gridExtra)
})

# 2) Point this to your desktop CSV. Edit only this line if your filename differs.
candidate_csv_paths <- c(
  file.path(Sys.getenv("HOME"), "Desktop", "atlas_vivli_2004_2024.csv"),
  "/Users/rawlingsgor/Desktop/atlas_vivli_2004_2024.csv"
)
input_csv <- candidate_csv_paths[file.exists(candidate_csv_paths)][1]

if (is.na(input_csv) || !file.exists(input_csv)) {
  input_csv <- file.choose()
}

# 3) Confirm that the repository files needed by the EDA are available.
if (!file.exists("R/atlas_amr_eda.R")) {
  stop("Run this from the AMR-agent project root so R/atlas_amr_eda.R is available.")
}
if (!dir.exists("config")) {
  stop("Run this from the AMR-agent project root so the config/ directory is available.")
}

# 4) Run the EDA script and generate reports/figures/tables.
dir.create("reports", showWarnings = FALSE)
rscript_bin <- file.path(R.home("bin"), "Rscript")
status <- system2(
  rscript_bin,
  args = c("R/atlas_amr_eda.R", shQuote(normalizePath(input_csv)), "reports"),
  stdout = TRUE,
  stderr = TRUE
)
cat(paste(status, collapse = "\n"), "\n")

# 5) Load key tables into the RStudio Environment for inspection.
data_quality_summary <- read_csv("reports/tables/data_quality_summary.csv", show_col_types = FALSE)
missingness_profile <- read_csv("reports/tables/missingness_profile.csv", show_col_types = FALSE)
top_lmic_eskape <- read_csv("reports/tables/top_lmic_eskape.csv", show_col_types = FALSE)
yearly_country <- read_csv("reports/tables/yearly_country.csv", show_col_types = FALSE)
pathogen_country <- read_csv("reports/tables/pathogen_country.csv", show_col_types = FALSE)

print(data_quality_summary)
print(missingness_profile)
print(head(top_lmic_eskape, 25))

# 6) Open the generated narrative findings file in RStudio if available.
findings_file <- normalizePath("reports/atlas_amr_eda_findings.md", mustWork = FALSE)
if (file.exists(findings_file) && interactive()) {
  file.edit(findings_file)
}

# 7) Display every generated PNG graph in the RStudio Plots pane.
plot_files <- list.files("reports/figures", pattern = "\\.png$", full.names = TRUE)
if (length(plot_files) == 0) {
  warning("No PNG files were generated. Check the console output above for EDA errors.")
} else {
  for (plot_file in plot_files) {
    img <- png::readPNG(plot_file)
    grid::grid.newpage()
    grid::grid.draw(grid::rasterGrob(img, interpolate = TRUE))
    grid::grid.text(
      basename(plot_file),
      x = 0.5,
      y = 0.98,
      gp = grid::gpar(fontsize = 13, fontface = "bold")
    )
    readline(prompt = "Press [enter] to show the next graph...")
  }
}

# 8) Optional: open output folders in the RStudio Files pane.
cat("\nEDA complete. Open these folders/files locally:\n")
cat("- Graphs: ", normalizePath("reports/figures", mustWork = FALSE), "\n", sep = "")
cat("- Tables: ", normalizePath("reports/tables", mustWork = FALSE), "\n", sep = "")
cat("- Findings: ", findings_file, "\n", sep = "")
cat("- Cleaned CSV: ", normalizePath("data/processed/atlas_amr_cleaned.csv", mustWork = FALSE), "\n", sep = "")
