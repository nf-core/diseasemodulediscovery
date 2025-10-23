#!/usr/bin/env python3
"""
drug_extractor.py

Utilities to extract drugs for a given disease from CSV edge/node files,
plus helper functions to filter by approval status and translate identifiers.
"""

import argparse
import ast
import csv
import logging
import os
import random
import sys
from typing import List, Dict, Optional
from typing import Union

import pandas as pd



# Configure root logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
_handler = logging.StreamHandler()
_handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s [%(name)s] %(message)s"))
logger.addHandler(_handler)


def load_csv(path: str) -> pd.DataFrame:
    """
    Load a CSV file into a pandas DataFrame.

    Parameters
    ----------
    path : str
        Path to the CSV file.

    Returns
    -------
    pd.DataFrame
        The loaded data.
    """
    # TODO: Add error handling for file not found or read errors
    logger.debug(f"Loading CSV from {path}")
    df = pd.read_csv(path)
    logger.info(f"Loaded {len(df)} rows from {path}")
    return df


def parse_list_column(df: pd.DataFrame, column: str) -> pd.DataFrame:
    """
    Parse columns that are stored as string representations of Python lists.

    Parameters
    ----------
    df : pd.DataFrame
        Input DataFrame.
    column : str
        Name of the column to parse.

    Returns
    -------
    pd.DataFrame
        DataFrame with `column` converted to actual Python lists.
    """
    logger.debug(f"Parsing list‐column '{column}'")
    df = df.copy()
    df[column] = df[column].apply(lambda s: ast.literal_eval(s) if pd.notna(s) else [])
    return df


def build_domainid_map(df: pd.DataFrame) -> Dict[str, str]:
    """
    Build a translation map from any domainId → primaryDomainId.

    Assumes the DataFrame has columns 'primaryDomainId' and 'domainIds' (as lists).

    Parameters
    ----------
    df : pd.DataFrame
        Node DataFrame (drugs or disorders).

    Returns
    -------
    Dict[str, str]
        Mapping from each alias domainId to its primaryDomainId.
    """
    logger.debug("Building domainId→primaryDomainId map")
    df = parse_list_column(df, "domainIds")
    mapping: Dict[str, str] = {}
    for _, row in df.iterrows():
        primary = row["primaryDomainId"]
        for did in row["domainIds"]:
            mapping[did] = primary
    logger.info(f"Built mapping of {len(mapping)} entries")
    return mapping


def translate_to_primary(domain_ids: List[str], mapping: Dict[str, str]) -> List[str]:
    """
    Translate a list of domainIds (aliases) to their primaryDomainIds.

    Parameters
    ----------
    domain_ids : List[str]
        List of domainIds or aliases.
    mapping : Dict[str, str]
        Alias→primary mapping.

    Returns
    -------
    List[str]
        List of primaryDomainIds (deduplicated).
    """
    primaries = {mapping.get(did, did) for did in domain_ids}
    return list(primaries)


def get_drugs_for_disease(edges_df: pd.DataFrame, disease_id: str) -> List[str]:
    """
    Given the edge DataFrame (drug_has_indication), return all sourceDomainIds
    (drugs) that have an indication for `disease_id`.

    Parameters
    ----------
    edges_df : pd.DataFrame
        Edge DataFrame with columns ['sourceDomainId', 'targetDomainId', …].
    disease_id : str
        primaryDomainId of the disease (e.g. 'mondo.0005494').

    Returns
    -------
    List[str]
        List of drug primaryDomainIds.
    """
    logger.debug(f"Querying drugs for disease: {disease_id}")
    # Filter rows matching the disease
    mask = edges_df["targetDomainId"] == disease_id
    drugs = edges_df.loc[mask, "sourceDomainId"].unique().tolist()
    logger.info(f"Found {len(drugs)} drugs for disease {disease_id}")
    return drugs


def is_drug_approved(drug_row: pd.Series) -> bool:
    """
    Check if a drug (row from drugs_df) is approved.

    Determines approval by checking if 'approved' is in the drugGroups list.

    Parameters
    ----------
    drug_row : pd.Series
        A row from the drugs DataFrame.

    Returns
    -------
    bool
        True if approved, False otherwise.
    """
    groups = ast.literal_eval(drug_row.get("drugGroups", "[]"))
    return "approved" in groups


def get_all_drugs(drugs_df: pd.DataFrame, approved_only: bool = False) -> List[str]:
    """
    Return all drug primaryDomainIds, optionally filtering for approved.

    Parameters
    ----------
    drugs_df : pd.DataFrame
        DataFrame loaded from drugs.csv.
    approved_only : bool, default False
        If True, return only approved drugs.

    Returns
    -------
    List[str]
        List of drug primaryDomainIds.
    """
    logger.debug(f"Getting all drugs; approved_only={approved_only}")
    if approved_only:
        mask = drugs_df.apply(is_drug_approved, axis=1)
        df = drugs_df.loc[mask]
        logger.info(f"Filtered down to {len(df)} approved drugs")
    else:
        df = drugs_df
        logger.info(f"Total drugs available: {len(df)}")
    return df["primaryDomainId"].tolist()


def translate_name_to_id(node_df: pd.DataFrame, name: str) -> Optional[str]:
    """
    Given a displayName / synonym, find the matching primaryDomainId.

    Parameters
    ----------
    node_df : pd.DataFrame
        Node DataFrame (disorders or drugs) with 'displayName' and 'synonyms'.
    name : str
        A human‐readable name (e.g. "adrenocortical insufficiency").

    Returns
    -------
    Optional[str]
        The matching primaryDomainId if found, else None.
    """
    logger.debug(f"Translating name '{name}' to domain ID")
    # Case‐insensitive match on displayName first
    match = node_df[node_df["displayName"].str.lower() == name.lower()]
    if not match.empty:
        return match.iloc[0]["primaryDomainId"]
    # Then search synonyms list
    df2 = parse_list_column(node_df, "synonyms")
    for _, row in df2.iterrows():
        if any(name.lower() == syn.lower() for syn in row["synonyms"]):
            return row["primaryDomainId"]
    logger.warning(f"No domain ID found for name '{name}'")
    return None


# --- Randomized drug list utilities ---
def randomize_drug_list(ids: List[str], length: int, seed: Optional[int] = None) -> List[List[Union[str, int]]]:
    """
    Generate a randomized ranked list of drug IDs from the given list.
    Args:
        ids (List[str]): List of drug IDs.
        length (int): Number of drugs to include in the randomized list.
        seed (Optional[int]): Random seed for reproducibility.
    Returns:
        List[List[Union[str, int]]]: List of [drug_id, rank] pairs.
    """
    if seed is not None:
        random.seed(seed)
    selected = random.sample(ids, k=min(length, len(ids)))
    return [[drug_id, rank] for rank, drug_id in enumerate(selected, start=1)]


def generate_random_lists(drugs_df: pd.DataFrame, count: int, seed: Optional[int] = None) -> List[
    List[List[Union[str, int]]]]:
    """
    Generate multiple randomized drug lists.
    Args:
        drugs_df (pd.DataFrame): DataFrame containing drug IDs.
        count (int): Number of randomized lists to generate.
        seed (Optional[int]): Base seed for reproducibility.
    Returns:
        List[List[List[Union[str, int]]]]: List containing `count` randomized lists.
    """
    ids = drugs_df["primaryDomainId"].tolist()
    length = len(ids)
    lists = []
    for i in range(count):
        current_seed = None if seed is None else seed + i
        print(i)
        lists.append(randomize_drug_list(ids, length, current_seed))
    return lists


def main():
    parser = argparse.ArgumentParser(description="Extract true drugs list for a given disease.")
    parser.add_argument('--drug-indicates', required=True, help="Path to the drug_has_indication CSV file.")
    parser.add_argument('--disease-id', required=True, help="PrimaryDomainId of the disease.")
    parser.add_argument('--output-folder', required=True, help="Path to output folder for trueDrugs list.")
    parser.add_argument('--output-file', default='true_drugs.csv',
        help="Filename for output CSV file (default: true_drugs.csv).")
    args = parser.parse_args()

    # Ensure output folder exists
    try:
        os.makedirs(args.output_folder, exist_ok=True)
        logger.info(f"Output folder '{args.output_folder}' is ready.")
    except OSError as e:
        logger.error(f"Failed to create output folder '{args.output_folder}': {e}")
        sys.exit(1)

    # Determine full output path
    output_path = os.path.join(args.output_folder, args.output_file)
    logger.debug(f"Output path set to '{output_path}'")

    edges_df = load_csv(args.drug_indicates)
    true_drugs = get_drugs_for_disease(edges_df, args.disease_id)

    out_df = pd.DataFrame({'trueDrugs': true_drugs})
    try:
        out_df.to_csv(output_path, index=False)
        logger.info(f"True drugs list saved to '{output_path}'")
    except IOError as e:
        logger.error(f"Failed to write true drugs list to '{output_path}': {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()


def load_drugs_list(file_path: str) -> List[List[Union[str, int]]]:
    """
    Reads a CSV file of drugs with columns including:
      drugId,label,status,drugstoneType,score,hasEdgesTo,isResult,isConnector

    Filters to isResult == True, sorts by score descending,
    and returns a ranked list of [ ["drugbank.<ID>", rank], ... ].

    Args:
        file_path: Path to the TSV file containing drug data.

    Returns:
        List[List[Union[str, int]]]: A list of lists, each containing a drug ID and its rank.
    """
    drugs = []
    with open(file_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            # Only include rows marked as results
            if row.get('isResult', '').strip().lower() == 'true':
                try:
                    score = float(row['score'])
                except (KeyError, ValueError):
                    continue
                drug_id = row['drugId'].strip()
                drugs.append((drug_id, score))

    # Sort by score descending
    drugs.sort(key=lambda x: x[1], reverse=True)

    # Build ranked list
    ranked = []
    for idx, (drug_id, _) in enumerate(drugs, start=1):
        ranked.append([f"drugbank.{drug_id}", idx])
    logger.debug("Ranked drugs: %s", ranked)
    return ranked
