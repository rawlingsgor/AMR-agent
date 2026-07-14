#!/usr/bin/env Rscript
# ATLAS/Vivli AMR EDA pipeline for the 2026 Vivli Data Challenge.
# Follows an EDA sequence: understand/import/inspect, clean missingness,
# transform features, visualize univariate-bivariate-multivariate structure,
# diagnose outliers, and communicate limitations.

suppressPackageStartupMessages({
  library(tidyverse)
  library(janitor)
  library(readr)
  library(scales)
})

args <- commandArgs(trailingOnly = TRUE)
input_path <- ifelse(length(args) >= 1, args[[1]], "data/raw/atlas_vivli_2004_2024.csv")
out_dir <- ifelse(length(args) >= 2, args[[2]], "reports")
fig_dir <- file.path(out_dir, "figures"); table_dir <- file.path(out_dir, "tables"); log_dir <- file.path(out_dir, "logs")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE); dir.create(table_dir, recursive = TRUE, showWarnings = FALSE); dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

stop_if_missing <- function(path) if (!file.exists(path)) stop("Input data not found: ", path, ". Place the Vivli ATLAS CSV at this path or pass it as the first argument.", call. = FALSE)
match_col <- function(nms, patterns) {
  hit <- nms[str_detect(nms, regex(patterns, ignore_case = TRUE))]
  if (length(hit) == 0) NA_character_ else hit[[1]]
}
write_csv_safe <- function(x, path) readr::write_csv(x, path, na = "")

stop_if_missing(input_path)
raw <- readr::read_csv(input_path, show_col_types = FALSE, progress = FALSE) |> janitor::clean_names()
col_dict <- readr::read_csv("config/column_dictionary.csv", show_col_types = FALSE)
eskape <- readr::read_csv("config/eskape_pathogens.csv", show_col_types = FALSE)
lmic <- readr::read_csv("config/lmic_countries.csv", show_col_types = FALSE) |> mutate(country_key = str_squish(str_to_lower(country)))

mapped <- col_dict |> mutate(source_column = map_chr(candidate_patterns, ~match_col(names(raw), .x)))
missing_required <- mapped |> filter(required == "yes", is.na(source_column))
if (nrow(missing_required) > 0) stop("Required columns could not be inferred: ", paste(missing_required$canonical_name, collapse = ", "), call. = FALSE)
write_csv_safe(mapped, file.path(log_dir, "column_mapping.csv"))

getv <- function(canon) { src <- mapped$source_column[mapped$canonical_name == canon][[1]]; if (is.na(src)) rep(NA, nrow(raw)) else raw[[src]] }
numv <- function(canon) parse_number(as.character(getv(canon)))

clean <- tibble(
  year = parse_number(as.character(getv("year"))),
  country = str_squish(as.character(getv("country"))),
  pathogen = str_squish(as.character(getv("pathogen"))),
  antibiotic = str_squish(as.character(getv("antibiotic"))),
  resistant = numv("resistant"), susceptible = numv("susceptible"), intermediate = numv("intermediate"),
  tested = numv("tested"), resistance_percent_raw = numv("resistance_percent"),
  income_group_source = str_squish(as.character(getv("income_group"))),
  region = str_squish(as.character(getv("region")))
) |>
  mutate(across(where(is.character), ~na_if(.x, "")), country_key = str_squish(str_to_lower(country))) |>
  left_join(lmic |> select(country_key, income_focus), by = "country_key") |>
  mutate(
    lmic_focus = !is.na(income_focus) | str_detect(str_to_lower(coalesce(income_group_source, "")), "low|middle|lmic|umic|lic"),
    tested = case_when(is.na(tested) & !is.na(resistant) & !is.na(susceptible) ~ resistant + susceptible + coalesce(intermediate, 0), TRUE ~ tested),
    resistance_rate = case_when(
      !is.na(resistant) & !is.na(tested) & tested > 0 ~ resistant / tested,
      !is.na(resistance_percent_raw) & resistance_percent_raw > 1 ~ resistance_percent_raw / 100,
      !is.na(resistance_percent_raw) ~ resistance_percent_raw,
      TRUE ~ NA_real_
    ),
    resistance_rate = if_else(resistance_rate < 0 | resistance_rate > 1, NA_real_, resistance_rate),
    pathogen_group = map_chr(str_to_lower(coalesce(pathogen, "")), function(x) {
      hit <- eskape$pathogen_group[str_detect(x, regex(eskape$pattern, ignore_case = TRUE))]
      if (length(hit) == 0) "Non-ESKAPE/Unmapped" else hit[[1]]
    }),
    eskape_flag = pathogen_group != "Non-ESKAPE/Unmapped",
    record_quality_flag = case_when(
      is.na(year) | is.na(country) | is.na(pathogen) ~ "missing_core_identifier",
      !is.na(tested) & tested <= 0 ~ "invalid_denominator",
      !is.na(resistant) & !is.na(tested) & resistant > tested ~ "resistant_exceeds_tested",
      TRUE ~ "analysis_ready"
    )
  )

qa <- tibble(metric = c("rows_raw", "columns_raw", "duplicate_rows_raw", "analysis_ready_rows", "lmic_rows", "eskape_rows"),
             value = c(nrow(raw), ncol(raw), sum(duplicated(raw)), sum(clean$record_quality_flag == "analysis_ready"), sum(clean$lmic_focus, na.rm = TRUE), sum(clean$eskape_flag, na.rm = TRUE)))
missingness <- clean |> summarise(across(everything(), ~sum(is.na(.x)))) |> pivot_longer(everything(), names_to = "variable", values_to = "missing_n") |> mutate(missing_pct = missing_n / nrow(clean)) |> arrange(desc(missing_pct))
write_csv_safe(qa, file.path(table_dir, "data_quality_summary.csv")); write_csv_safe(missingness, file.path(table_dir, "missingness_profile.csv")); write_csv_safe(clean, "data/processed/atlas_amr_cleaned.csv")

analysis <- clean |> filter(record_quality_flag == "analysis_ready", !is.na(resistance_rate))
outliers <- analysis |> group_by(pathogen_group, antibiotic) |> mutate(q1 = quantile(resistance_rate, .25, na.rm = TRUE), q3 = quantile(resistance_rate, .75, na.rm = TRUE), iqr = q3 - q1, outlier_iqr = resistance_rate < q1 - 1.5*iqr | resistance_rate > q3 + 1.5*iqr) |> ungroup()
write_csv_safe(outliers |> filter(outlier_iqr), file.path(table_dir, "iqr_outlier_records_review_not_removed.csv"))

save_plot <- function(p, name, w=11, h=7) ggsave(file.path(fig_dir, name), p, width=w, height=h, dpi=300)
save_plot(ggplot(analysis, aes(resistance_rate)) + geom_histogram(bins=40, fill="#2c7fb8") + scale_x_continuous(labels=percent) + labs(title="Distribution of AMR resistance rates", x="Resistance rate", y="Records"), "hist_resistance_rate.png")
save_plot(ggplot(analysis, aes(x=reorder(pathogen_group, resistance_rate, median), y=resistance_rate, fill=eskape_flag)) + geom_boxplot(outlier.alpha=.35) + coord_flip() + scale_y_continuous(labels=percent) + labs(title="Resistance-rate spread by pathogen group", x=NULL, y="Resistance rate"), "boxplot_pathogen_resistance.png")
save_plot(analysis |> count(pathogen_group, sort=TRUE) |> ggplot(aes(reorder(pathogen_group, n), n, fill=pathogen_group)) + geom_col(show.legend=FALSE) + coord_flip() + labs(title="Pathogen-group record volume", x=NULL, y="Records"), "bar_pathogen_volume.png")
save_plot(analysis |> count(lmic_focus) |> mutate(label=if_else(lmic_focus, "LMIC focus", "Other/unknown"), pct=n/sum(n)) |> ggplot(aes("", pct, fill=label)) + geom_col(width=1) + coord_polar("y") + geom_text(aes(label=percent(pct)), position=position_stack(vjust=.5)) + labs(title="Share of analysis records by LMIC focus", x=NULL, y=NULL, fill=NULL), "pie_lmic_share.png", 7, 7)
save_plot(analysis |> group_by(year, lmic_focus, eskape_flag) |> summarise(median_rate=median(resistance_rate), n=n(), .groups="drop") |> ggplot(aes(year, median_rate, color=lmic_focus, linetype=eskape_flag)) + geom_line(linewidth=1) + geom_point(aes(size=n), alpha=.6) + scale_y_continuous(labels=percent) + labs(title="Resistance trends by LMIC and ESKAPE focus", y="Median resistance rate", color="LMIC", linetype="ESKAPE"), "trend_lmic_eskape.png")
save_plot(analysis |> filter(eskape_flag, lmic_focus) |> group_by(pathogen_group, antibiotic) |> summarise(median_rate=median(resistance_rate), n=n(), .groups="drop") |> filter(n >= 5) |> ggplot(aes(antibiotic, pathogen_group, fill=median_rate)) + geom_tile() + scale_fill_viridis_c(labels=percent) + labs(title="LMIC ESKAPE pathogen-antibiotic median resistance heat map", x="Antibiotic", y="Pathogen", fill="Median"), "heatmap_lmic_eskape_antibiotic.png", 14, 7)
save_plot(analysis |> filter(!is.na(tested)) |> ggplot(aes(tested, resistance_rate, color=lmic_focus)) + geom_point(alpha=.35) + scale_x_log10(labels=comma) + scale_y_continuous(labels=percent) + labs(title="Resistance rate versus testing denominator", x="Tested denominator (log scale)", y="Resistance rate", color="LMIC"), "scatter_denominator_resistance.png")

summary_tables <- list(
  top_lmic_eskape = analysis |> filter(lmic_focus, eskape_flag) |> group_by(country, pathogen_group, antibiotic) |> summarise(records=n(), tested=sum(tested, na.rm=TRUE), median_rate=median(resistance_rate), .groups="drop") |> arrange(desc(median_rate), desc(tested)),
  yearly_country = analysis |> group_by(year, country, lmic_focus) |> summarise(records=n(), median_rate=median(resistance_rate), .groups="drop"),
  pathogen_country = analysis |> filter(eskape_flag) |> group_by(country, pathogen_group, lmic_focus) |> summarise(records=n(), median_rate=median(resistance_rate), .groups="drop")
)
iwalk(summary_tables, ~write_csv_safe(.x, file.path(table_dir, paste0(.y, ".csv"))))

sink(file.path(out_dir, "atlas_amr_eda_findings.md"))
cat("# ATLAS/Vivli AMR EDA Findings\n\n")
cat("Generated: ", as.character(Sys.time()), " UTC\n\n", sep="")
cat("## Data-quality safeguards\n- Core identifiers are year, country, and pathogen; records missing these are flagged, not silently imputed.\n- Resistance rates outside [0,1], impossible denominators, and resistant counts greater than tested are excluded from analysis-ready summaries.\n- IQR outliers are exported for review but retained in visual context unless structurally invalid, because extreme AMR rates may be true local signals.\n\n")
cat("## Key generated outputs\n- `tables/data_quality_summary.csv` and `tables/missingness_profile.csv` document completeness and cleaning decisions.\n- `figures/` contains histograms, bar charts, pie chart, scatter plot, box plot, heat map, and trends.\n- `tables/top_lmic_eskape.csv` prioritizes high-granularity LMIC ESKAPE pathogen-drug-country findings.\n\n")
cat("## Limitations\n- Income classification is supplied by `config/lmic_countries.csv` and should be updated against the challenge's approved source before final submission.\n- Aggregate ATLAS/Vivli records can reflect surveillance intensity, sampling design, and laboratory coverage rather than population incidence.\n- Missingness and outliers are made explicit; unverifiable values are not over-imputed to avoid bias.\n")
sink()
message("EDA completed. Outputs written under ", out_dir)
