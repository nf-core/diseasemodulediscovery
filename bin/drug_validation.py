#!/usr/bin/env python
import argparse
import logging
import math
import os
import random
import sys
from typing import List, Optional, Union, Dict

import pandas as pd

from extract_true_drugs import is_drug_approved, load_drugs_list
from extract_true_drugs import load_csv

# Constants

# Configure logger
logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)
_handler = logging.StreamHandler()
_handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s [%(name)s] %(message)s"))
logger.addHandler(_handler)


def calculate_dcg(true_drugs: List[str], candidates: List[List[Union[str, int]]]) -> float:
    """
    Calculates Discounted Cumulative Gain (DCG) for candidate drugs given ground truth drugs.
    Args:
        true_drugs (List[str]): List of relevant drug IDs.
        candidates (List[List[Union[str, int]]]): List of [drug_id, rank] pairs sorted by rank.
    Returns:
        float: DCG score.
    """
    # Ensure candidates are sorted by their provided rank
    sorted_candidates = sorted(candidates, key=lambda x: x[1])
    dcg = 0.0
    for position, (drug_id, _) in enumerate(sorted_candidates, start=1):
        if drug_id in true_drugs:
            dcg += 1.0 / math.log(position + 1, 2)
    return dcg


def generate_random_distributions(drugs_df: pd.DataFrame, true_drugs: List[str], length: int, count: int,
                                  seed: Optional[int] = None, approved_only: bool = False) -> (List[float], List[int]):
    """
    Generate distributions of DCG scores and overlap counts from random drug rankings,
    sampling and scoring each permutation on the fly.

    Args:
        drugs_df (pd.DataFrame): DataFrame with a "primaryDomainId" column.
        true_drugs (List[str]): Ground‐truth relevant drug IDs.
        length (int): How many drugs to sample/rank per permutation.
        count (int): Number of random permutations to generate samples for.
        seed (Optional[int]): Base random seed for reproducibility.
        approved_only (bool): If True, only sample from approved drugs.
    Returns:
        Tuple[List[float], List[int]]: Lists of DCG values and overlap counts.
    """
    if approved_only:
        drugs_df = drugs_df[drugs_df.apply(is_drug_approved, axis=1)]
    ids = drugs_df["primaryDomainId"].tolist()
    dcg_values: List[float] = []
    overlap_values: List[int] = []
    for i in range(count):
        if seed is not None:
            random.seed(seed + i)
        sample_ids = random.sample(ids, k=min(length, len(ids)))
        dcg = 0.0
        overlap = 0
        for pos, drug_id in enumerate(sample_ids, start=1):
            if drug_id in true_drugs:
                dcg += 1.0 / math.log2(pos + 1)
                overlap += 1
        dcg_values.append(dcg)
        overlap_values.append(overlap)
    return dcg_values, overlap_values


def main():
    parser = argparse.ArgumentParser(
        description="Perform (local) statistical validation of drug prioritization results.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--candidate-drugs', required=True, help="Candidate drug results from drug prioritization tool")
    parser.add_argument('--drug-list', required=True, help="Path to the complete drug list CSV file for sampling")
    parser.add_argument('--permutation-count', type=int, default=10000,
                        help="Number of random permutations to generate for DCG comparison")
    parser.add_argument('--only-approved', action='store_true', help="Only consider approved drugs in the validation")
    parser.add_argument('--true-drugs', required=True,
                        help="Path to the true drugs list CSV file containing ground truth relevant drug IDs")
    parser.add_argument('--out-dir', required=True, help="Directory to save the validation results")
    parser.add_argument('--output-file', default='drug_validation_results.tsv',
                        help="Output file name for the validation results in TSV format")
    parser.add_argument('--id', default=None,
                        help="ID for output row; defaults to basename of candidate-drugs file")
    args = parser.parse_args()
    # Derive output ID from candidate-drugs basename if not provided
    if args.id is None:
        id_value = os.path.splitext(os.path.basename(args.candidate_drugs))[0]
    else:
        id_value = args.id
    # Verify that the output directory exists or create it, and ensure it's a directory
    if not os.path.exists(args.out_dir):
        try:
            os.makedirs(args.out_dir)
            logger.info(f"Created output directory '{args.out_dir}'")
        except OSError as e:
            logging.error(f"Could not create output directory '{args.out_dir}': {e}")
            sys.exit(1)
    elif not os.path.isdir(args.out_dir):
        logging.error(f"Output path '{args.out_dir}' exists and is not a directory")
        sys.exit(1)

    true_drugs = load_csv(args.true_drugs)["trueDrugs"].tolist()

    # Load candidate drugs
    candidates = load_drugs_list(args.candidate_drugs)
    logger.debug(f"Loaded {len(candidates)} candidate drugs from {args.candidate_drugs}")
    drugs_df = load_csv(args.drug_list)

    # generate distributions of DCG values and overlap counts
    permutation_count = args.permutation_count
    only_approved = args.only_approved

    result = drug_list_validation(drugs_df, true_drugs, candidates, permutation_count, only_approved)
    # Save results to TSV file
    output_file = os.path.join(args.out_dir, args.output_file)
    try:
        header = [
            'ID',
            'empirical_DCG_based_p_value',
            'empirical_p_value_without_considering_ranks',
            'observed_DCG',
            'observed_overlap',
            'dcg_exceed_count',
            'overlap_exceed_count',
            'candidate_count',
            'percent_true_drugs_found',
            'true_drugs_file'
        ]
        with open(output_file, 'w') as f:
            f.write('\t'.join(header) + '\n')
            row = [
                id_value,
                str(result['empirical DCG-based p-value']),
                str(result['empirical p-value without considering ranks']),
                str(result['observed DCG']),
                str(result['observed overlap']),
                str(result['dcg exceed count']),
                str(result['overlap exceed count']),
                str(result['candidate count']),
                str(result['percent true drugs found']),
                args.true_drugs
            ]
            f.write('\t'.join(row) + '\n')
        logger.info(f"Results successfully saved to '{output_file}'")
    except IOError as e:
        logger.error(f"Failed to write results to '{output_file}': {e}")
        sys.exit(1)


def drug_list_validation(drugs_df: pd.DataFrame, true_drugs: List[str], candidates: List[List[Union[str, int]]],
                         permutation_count: int, only_approved: bool) -> Dict[str, Union[float, int]]:
    """
    Perform empirical validation of drug prioritization results comparing an observed candidate list against random distributions.

    Args:
        drugs_df (pd.DataFrame): DataFrame with a "primaryDomainId" column containing all drug IDs for sampling.
        true_drugs (List[str]): List of ground truth relevant drug IDs.
        candidates (List[List[Union[str, int]]]): List of [drug_id, rank] pairs representing candidate drugs.
        permutation_count (int): Number of random permutations to generate for DCG comparison.
        only_approved (bool): If True, only sample from approved drugs based on is_drug_approved.

    Returns:
        Dict[str, Union[float, int]]: Dictionary containing:
            - "empirical DCG-based p-value" (float)
            - "empirical p-value without considering ranks" (float)
            - "observed DCG" (float)
            - "observed overlap" (int)
    """
    dcg_observed = calculate_dcg(true_drugs, candidates)
    # Log how many drugs were observed
    logger.info(f"Observed DCG: {dcg_observed} for {len(candidates)} candidate drugs")
    dcg_random, overlap_random = generate_random_distributions(drugs_df, true_drugs, length=len(candidates),
                                                               count=permutation_count, approved_only=only_approved)
    logger.debug(f"Generated {len(dcg_random)} random DCG values and {len(overlap_random)} overlap counts")
    # empirical DCG-based p-value
    exceed_dcg = sum(1 for v in dcg_random if v >= dcg_observed)
    p_value_dcg = (exceed_dcg + 1) / (permutation_count + 1)
    # observed overlap ignoring ranks
    observed_overlap = sum(1 for drug_id, _ in candidates if drug_id in true_drugs)
    # empirical overlap-based p-value
    exceed_overlap = sum(1 for o in overlap_random if o >= observed_overlap)
    p_value_overlap = (exceed_overlap + 1) / (permutation_count + 1)
    logger.info(f"Observed DCG: {dcg_observed}, DCG p-value: {p_value_dcg}")
    logger.info(f"Observed overlap: {observed_overlap}, overlap p-value: {p_value_overlap}")
    # number of exceeding cases
    logger.info(f"Number of random DCG values exceeding observed: {exceed_dcg} out of {permutation_count}")
    logger.info("Validation completed successfully")
    return {
        "empirical DCG-based p-value": p_value_dcg,
        "empirical p-value without considering ranks": p_value_overlap,
        "observed DCG": dcg_observed,
        "observed overlap": observed_overlap,
        "dcg exceed count": exceed_dcg,
        "overlap exceed count": exceed_overlap,
        "candidate count": len(candidates),
        "percent true drugs found": (observed_overlap / len(true_drugs) * 100) if candidates else 0.0
    }


if __name__ == '__main__':
    # sys.argv = ['drug_validation.py', '--drug-list', '../../data/nedrexDB/drug.csv', '--permutation-count', '100000','--true-drugs', '../../data/true_drugs.csv', "--only-approved", '--candidate-drugs','../../data/PipelineTestOut/drug_prioritization/drugstone/entrez_seeds_1.entrez_ppi.diamond.trustrank.csv','--out-dir', '../../data/drug_validation_results']
    main()
