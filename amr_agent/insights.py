"""Lightweight insight agent over generated ATLAS AMR EDA tables.

This module intentionally keeps provenance explicit: every answer points back to
specific EDA tables created by `R/atlas_amr_eda.R` so challenge reviewers can
trace conclusions to reproducible artifacts.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import pandas as pd


@dataclass(frozen=True)
class AMRInsightAgent:
    """Question-answer helper for LMIC and ESKAPE AMR surveillance summaries."""

    reports_dir: Path = Path("reports")

    def _table(self, name: str) -> pd.DataFrame:
        path = self.reports_dir / "tables" / name
        if not path.exists():
            raise FileNotFoundError(
                f"Missing {path}. Run `Rscript R/atlas_amr_eda.R <csv> reports` first."
            )
        return pd.read_csv(path)

    def top_lmic_eskape(self, n: int = 10) -> pd.DataFrame:
        """Return highest median resistance LMIC ESKAPE country-pathogen-drug cells."""
        df = self._table("top_lmic_eskape.csv")
        cols = ["country", "pathogen_group", "antibiotic", "records", "tested", "median_rate"]
        available = [col for col in cols if col in df.columns]
        return df.loc[:, available].head(n)

    def data_quality(self) -> pd.DataFrame:
        """Return auditable EDA quality metrics."""
        return self._table("data_quality_summary.csv")

    def missingness(self) -> pd.DataFrame:
        """Return missingness profile sorted by missing percentage."""
        df = self._table("missingness_profile.csv")
        if "missing_pct" in df.columns:
            return df.sort_values("missing_pct", ascending=False)
        return df
