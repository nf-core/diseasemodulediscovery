#!/usr/bin/env python

import argparse
import logging
import sys
from pathlib import Path
import pandas as pd

logger = logging.getLogger()


def parse_args(argv=None):
    """Define and immediately parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Compute a combined score for each module based on multiple evaluation metrics.",
        epilog="Example: python aggregate_scores.py --list_score_paths file1 file2",
    )
    parser.add_argument(
        "--list_score_paths",
        help="A list of TSV files providing scores for each module.",
        type=Path,
        nargs="+",
        required=True,
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="The desired log level (default WARNING).",
        choices=("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"),
        default="WARNING",
    )
    return parser.parse_args(argv)


def load_digest_tsvs(path):
    """
    Load the Digest TSV file(s), min-max scale the four scores,
    and aggregate them (mean) into one score column.

    Args:
        path (str or Path): Path to the Digest TSV file.

    Returns:
        pandas.DataFrame: DataFrame with two columns: "id" and "score_{method}",
                          where {method} is derived from the file name.
    """

    df = pd.read_csv(path, sep="\t")

    name_method = path.stem.split("_mqc")[0]

    score_cols = df.columns[1:]  # all columns except the first one (module column)
    # min-max scaling of all columns
    df_min_max_scaled, scaled_cols = min_max_scaling(df, score_cols=score_cols)

    if df_min_max_scaled is not None:
        # aggregate all the scaled columns in one column named using the file
        df_aggregated = aggregate_scores(
            df_min_max_scaled,
            scaled_cols=scaled_cols,
            output_col=f"score_{name_method}",
        )

        df_aggregated = df_aggregated.rename(columns={df.columns[0]: "id"})

        return df_aggregated[[df_aggregated.columns[0], f"score_{name_method}"]]

    else:
        return None


def load_seed_perturbation_tsv(path):
    """
    Load the seed perturbation TSV file, min-max scale the normalized rediscovery rate
    column and the avg_jaccard_index column as is.

    Args:
        path (str or Path): Path to the seed perturbation TSV file.

    Returns:
        pandas.DataFrame: DataFrame with three columns:
                            - "id",
                            - "score_seed_perturbation_avg_jaccard_index",
                            - "score_seed_perturbation_normalized_rediscovery_rate"
    """
    df = pd.read_csv(path, sep="\t")

    # min-max scale all the columns except the module column
    df_scaled, scaled_cols = min_max_scaling(df)

    # keep the specified columns and the new combined score column, and rename them
    rename_map = {
        df.columns[0]: "id",
        "avg_jaccard_index_scaled": "score_seed_perturbation_avg_jaccard_index",
        "normalized_rediscovery_rate_scaled": "score_seed_perturbation_normalized_rediscovery_rate",
    }

    col_to_keep = [
        df.columns[0],
        "avg_jaccard_index_scaled",
        "normalized_rediscovery_rate_scaled",
    ]

    if df_scaled is not None:
        for col in ["avg_jaccard_index_scaled", "normalized_rediscovery_rate_scaled"]:
            if col not in scaled_cols:
                print(
                    f"Warning: {col} from file {path} was not scaled and will not be included in the output."
                )
                col_to_keep.remove(col)
                rename_map.pop(col, None)

        df_final = df_scaled[col_to_keep].rename(columns=rename_map)

        return df_final

    else:
        return None


def load_network_perturbation_tsv(path):
    """
    Load the network perturbation TSV file, min-max scale the score column,
    invert the scaled column (1-score), and rename it with the file stem.

    Args:
        path (str or Path): Path to the network perturbation TSV file.

    Returns:
        pandas.DataFrame: DataFrame with two columns: "id" and "score_{method}",
                          where {method} is derived from the file name.
    """
    df = pd.read_csv(path, sep="\t")

    # min-max scale all columns except the module column
    # reverse the avg_jaccard_index column after scaling because lower values are better
    df_scaled, scaled_cols = min_max_scaling(df, reverse_cols=["avg_jaccard_index"])

    if df_scaled is not None:
        # rename the scaled score column with the file stem
        col_to_keep = [df.columns[0]]
        for col in scaled_cols:
            if col in df_scaled.columns:
                new_col_name = (
                    f"score_network_perturbation_{col.replace('_scaled', '')}"
                )
                df_scaled = df_scaled.rename(columns={col: new_col_name})
                col_to_keep.append(new_col_name)
            else:
                print(
                    f"Warning: {col} from file {path} was not scaled and will not be included in the output."
                )

        df_scaled = df_scaled[col_to_keep].rename(columns={df_scaled.columns[0]: "id"})

        return df_scaled

    else:
        return None


def min_max_scaling(df, score_cols=None, reverse_cols=None, suffix="_scaled"):
    """
    Min-max scale score columns to [0, 1].

    Args:
        df : pandas.DataFrame
        score_cols : list[str] or None
            Columns to scale. If None, all columns are used.
        reverse_cols : list[str] or None
            Columns where lower values are indicating a better result.
            These are inverted after scaling.
        suffix : str
            Suffix added to scaled columns.

    Returns:
        scaled_df : pandas.DataFrame
        scaled_cols : list[str]
    """
    result = df.copy()

    if score_cols is None:
        score_cols = df.columns[1:]

    scaled_cols = []

    # scale each score column independently
    for col in score_cols:
        values = pd.to_numeric(result[col], errors="coerce")
        min_val = values.min(skipna=True)
        max_val = values.max(skipna=True)

        scaled_col = f"{col}{suffix}"

        # skip the column if it cannot be scaled
        # (e.g. all values are the same or all values are NaN)
        if pd.notna(min_val) and pd.notna(max_val) and max_val != min_val:

            scaled = (values - min_val) / (max_val - min_val)
            if reverse_cols is not None and col in reverse_cols:
                scaled = 1.0 - scaled
            result[scaled_col] = scaled

            scaled_cols.append(scaled_col)

    if len(scaled_cols) > 0:
        return result, scaled_cols

    else:
        print("Warning: No columns were scaled.")
        return None, []


def aggregate_scores(df, scaled_cols, output_col="aggregated_score"):
    """
    Aggregate score columns into one score per module (take the mean).

    Args:
        df : pandas.DataFrame
        scaled_cols : list[str]
            List of columns to aggregate.
        output_col : str
            Name of the output column for the aggregated score.

    Returns:
        pandas.DataFrame with the original columns plus the new aggregated score column.
    """
    result = df.copy()
    result[output_col] = result[scaled_cols].mean(axis=1, skipna=True)

    return result.sort_values(output_col, ascending=False).reset_index(drop=True)


def main(argv=None):
    """
    Coordinate argument parsing and program execution:
    Load one or more TSV files, perform min-max scaling and aggregation,
    and create a final score (mean of all scores)).

    Each TSV file must contain:
    - one module column (the first column)
    - one score column
    - one or more module rows

    Args:
        paths (list[str or Path]): List of paths to the TSV files.

    Returns:
        pandas.DataFrame: DataFrame with columns:
            - "id" (module identifier)
            - score(s) for each method
            - "combined_score" (mean of all score columns)
    """
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")

    merged_df = None

    for path in map(Path, args.list_score_paths):

        # Read and prepare the data based on the file type
        # (digest, seed perturbation, or network perturbation)
        if "digest" in path.stem.lower():
            df = load_digest_tsvs(path)

        elif "seed_perturbation" in path.stem.lower():
            df = load_seed_perturbation_tsv(path)

        elif "network_perturbation" in path.stem.lower():
            df = load_network_perturbation_tsv(path)

        else:
            print(f"Warning: Unrecognized file type for {path}. Skipping this file.")
            df = None

        # Merge
        if merged_df is None:
            merged_df = df
        elif df is not None:
            # Use outer join to ensure we don't lose modules missing in some files
            merged_df = pd.merge(merged_df, df, on=df.columns[0], how="outer")

    try:
        # Finally create a combined score column by averaging all the score columns (ignoring NaNs)
        score_cols = merged_df.columns[1:]
        merged_df["combined_score"] = merged_df[score_cols].mean(axis=1, skipna=True)

        # write multiqc summary
        with open("aggregated_scores_summary.tsv", "w") as f:
            merged_df.to_csv(f, sep="\t", index=False)

    except Exception as e:
        print(f"Error occurred while creating combined score: {e}")
        return None


if __name__ == "__main__":
    sys.exit(main())
