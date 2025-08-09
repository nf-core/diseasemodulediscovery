#!/usr/bin/env python3
"""
create_true_drug_file.py

Build a disease-specific list of drugs that:
1) exist in the drug node CSV
2) optionally are approved (drugGroups contains "approved")
3) have at least one target in drug_has_target
4) are indicated for the given disease in drug_has_indication

Output: CSV with a single column "trueDrugs".

Examples
--------
python true_targeted_drugs.py \
  --drug-has-indication ./edges/drug_has_indication.csv \
  --drug-has-target ./edges/drug_has_target.csv \
  --drug-csv ./nodes/drug.csv \
  --disease-id mondo.0000190 \
  --only-approved \
  --output-folder ./out

If --output-file is not given the default is "<disease-id>.csv" inside --output-folder.
"""

from __future__ import annotations

import argparse
import ast
import logging
import sys
from pathlib import Path
from typing import Iterable, List, Set

import pandas as pd


# ------------------------------- Logging ------------------------------------ #

def setup_logger(level: str = "INFO") -> logging.Logger:
    logger = logging.getLogger("true_targeted_drugs")
    if not logger.handlers:
        handler = logging.StreamHandler()
        formatter = logging.Formatter(
            "%(asctime)s %(levelname)s [%(name)s] %(message)s"
        )
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    logger.setLevel(getattr(logging, level.upper(), logging.INFO))
    # Silence noisy libs unless user raises level to DEBUG
    logging.getLogger("urllib3").setLevel(logging.WARNING)
    logging.getLogger("chardet").setLevel(logging.WARNING)
    return logger


# ------------------------------- IO utils ----------------------------------- #

def load_csv(path: Path, logger: logging.Logger, **read_csv_kwargs) -> pd.DataFrame:
    if not path.exists() or not path.is_file():
        logger.error(f"CSV not found: {path}")
        sys.exit(1)
    try:
        logger.debug(f"Loading CSV: {path}")
        df = pd.read_csv(path, **read_csv_kwargs)
        logger.info(f"Loaded {len(df)} rows from {path.name}")
        return df
    except Exception as e:
        logger.error(f"Failed to read {path}: {e}")
        sys.exit(1)


def ensure_dir(path: Path, logger: logging.Logger) -> None:
    try:
        path.mkdir(parents=True, exist_ok=True)
        logger.debug(f"Output folder ready: {path}")
    except Exception as e:
        logger.error(f"Failed to create output folder '{path}': {e}")
        sys.exit(1)


# --------------------------- Parsing helpers -------------------------------- #

def parse_list_str(s) -> List:
    """Safely parse a Python list stored as a string. Returns [] on failure."""
    if pd.isna(s) or s is None or str(s).strip() == "":
        return []
    try:
        val = ast.literal_eval(s)
        return val if isinstance(val, list) else []
    except Exception:
        return []


# ----------------------------- Core logic ----------------------------------- #

def get_all_drug_ids(drugs_df: pd.DataFrame) -> Set[str]:
    return set(drugs_df["primaryDomainId"].dropna().astype(str).tolist())


def get_approved_drug_ids(drugs_df: pd.DataFrame) -> Set[str]:
    if "drugGroups" not in drugs_df.columns:
        return set()
    groups = drugs_df["drugGroups"].apply(parse_list_str)
    mask = groups.apply(lambda lst: "approved" in lst)
    return set(drugs_df.loc[mask, "primaryDomainId"].dropna().astype(str).tolist())


def get_drugs_with_targets(target_df: pd.DataFrame) -> Set[str]:
    if "sourceDomainId" not in target_df.columns:
        return set()
    return set(target_df["sourceDomainId"].dropna().astype(str).unique().tolist())


def get_drugs_for_disease(ind_df: pd.DataFrame, disease_id: str) -> Set[str]:
    required_cols = {"sourceDomainId", "targetDomainId"}
    if not required_cols.issubset(set(ind_df.columns)):
        return set()
    mask = ind_df["targetDomainId"].astype(str) == disease_id
    return set(ind_df.loc[mask, "sourceDomainId"].dropna().astype(str).unique().tolist())


def compute_true_drugs(
    drugs_df: pd.DataFrame,
    targets_df: pd.DataFrame,
    indication_df: pd.DataFrame,
    disease_id: str,
    only_approved: bool,
    logger: logging.Logger,
) -> List[str]:
    all_drugs = get_all_drug_ids(drugs_df)
    logger.debug(f"Total drugs in node CSV: {len(all_drugs)}")

    if only_approved:
        allowed = get_approved_drug_ids(drugs_df)
        logger.info(f"Filtering to approved drugs: {len(allowed)} remain")
    else:
        allowed = all_drugs
        logger.info(f"No approval filter applied: {len(allowed)} allowed")

    with_targets = get_drugs_with_targets(targets_df)
    logger.info(f"Drugs with targets: {len(with_targets)}")

    disease_drugs = get_drugs_for_disease(indication_df, disease_id)
    logger.info(f"Drugs indicated for {disease_id}: {len(disease_drugs)}")

    # Intersections
    candidate = allowed.intersection(with_targets)
    logger.debug(f"Allowed  has-targets: {len(candidate)}")
    true_drugs = sorted(candidate.intersection(disease_drugs))

    logger.info(f"Final trueDrugs count: {len(true_drugs)}")
    return true_drugs


# ------------------------------ CLI parsing --------------------------------- #

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build disease-specific list of targeted drugs with optional approval filter."
    )

    # Accept canonical flags and forgiving aliases for the typos provided
    parser.add_argument(
        "--drug-has-indication", "--drug-has_inidication",
        dest="drug_has_indication",
        required=True,
        help="Path to drug_has_indication CSV",
    )
    parser.add_argument(
        "--drug-has-target",
        dest="drug_has_target",
        required=True,
        help="Path to drug_has_target CSV",
    )
    parser.add_argument(
        "--drug-csv",
        dest="drug_csv",
        required=True,
        help="Path to drug node CSV (e.g., drug.csv)",
    )
    parser.add_argument(
        "--disease-id", "--diseease-id",
        dest="disease_id",
        required=True,
        help="PrimaryDomainId of the disease (e.g., mondo.0000190)",
    )
    parser.add_argument(
        "--only-approved",
        dest="only_approved",
        action="store_true",
        default=False,
        help="If set, restrict to approved drugs",
    )
    parser.add_argument(
        "--output-folder",
        dest="output_folder",
        default=".",
        help="Output folder. Default is current working directory",
    )
    parser.add_argument(
        "--output-file",
        dest="output_file",
        default=None,
        help="Output CSV filename. Default is '<disease-id>.csv'",
    )
    parser.add_argument(
        "--log-level",
        dest="log_level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Logging level. Default INFO",
    )

    return parser.parse_args()


# ---------------------------------- Main ------------------------------------ #

def main() -> None:
    args = parse_args()
    logger = setup_logger(args.log_level)

    # Resolve paths
    drug_has_ind_path = Path(args.drug_has_indication).expanduser().resolve()
    drug_has_target_path = Path(args.drug_has_target).expanduser().resolve()
    drug_csv_path = Path(args.drug_csv).expanduser().resolve()

    # Load CSVs
    ind_df = load_csv(drug_has_ind_path, logger)
    tgt_df = load_csv(drug_has_target_path, logger)
    drugs_df = load_csv(drug_csv_path, logger)

    # Compute true drugs
    true_drugs = compute_true_drugs(
        drugs_df=drugs_df,
        targets_df=tgt_df,
        indication_df=ind_df,
        disease_id=str(args.disease_id),
        only_approved=bool(args.only_approved),
        logger=logger,
    )

    if len(true_drugs) == 0:
        logger.error("No drugs matched the criteria. Exiting with error.")
        sys.exit(2)

    # Prepare output
    out_dir = Path(args.output_folder).expanduser().resolve()
    ensure_dir(out_dir, logger)
    out_file = args.output_file or f"{args.disease_id}.csv"
    out_path = out_dir / out_file

    # Save
    try:
        pd.DataFrame({"trueDrugs": true_drugs}).to_csv(out_path, index=False)
        logger.info(f"Wrote {len(true_drugs)} rows to {out_path}")
    except Exception as e:
        logger.error(f"Failed to write output CSV '{out_path}': {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
