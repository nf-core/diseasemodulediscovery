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
        description="Calculate overlap matrices",
        epilog="Example: python module_overlap.py --ids id1 id2 --inputs file1 file2",
    )
    parser.add_argument(
        "--ids",
        type=str,
        help="IDs to name the columns/rows of the output matrix",
        nargs="+",
        required=True,
    )
    parser.add_argument(
        "--inputs",
        help="A list of TSV files providing module node lists with at least two columns 'name' and 'is_seed'.",
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


def pairwise_matrix(sets, set_names, function):
    df = pd.DataFrame(columns=set_names)
    for set_1, name_1 in zip(sets, set_names):
        row = {name_2: function(set_1, set_2) for set_2, name_2 in zip(sets, set_names)}
        df.loc[len(df)] = row
    df.insert(1, "ID", set_names, True)
    df.set_index("ID", inplace=True)
    return df


def jaccard(set_1, set_2):
    return len(set_1.intersection(set_2)) / len(set_1.union(set_2))


def shared_nodes(set_1, set_2):
    return len(set_1.intersection(set_2))


def main(argv=None):
    """Coordinate argument parsing and program execution."""
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")

    assert len(args.ids) == len(args.inputs)

    module_map = {}
    module_map_no_seeds = {}
    for id, file in zip(args.ids, args.inputs):
        df = pd.read_csv(file, sep="\t")

        assert set(["name", "is_seed"]).issubset(df.columns)
        assert df["is_seed"].isin([0, 1]).all()

        module_map[id] = set(df["name"])
        module_map_no_seeds[id] = set(df[df["is_seed"] == 0]["name"])

    # Sort the module map by ID for consistent output
    module_map = dict(sorted(module_map.items()))
    ids, modules = zip(*module_map.items())

    jaccard_df = pairwise_matrix(modules, ids, jaccard)
    jaccard_df.to_csv("jaccard_similarity_matrix_mqc.tsv", sep="\t")

    shared_nodes_df = pairwise_matrix(modules, ids, shared_nodes)
    shared_nodes_df.to_csv("shared_nodes_matrix_mqc.tsv", sep="\t")

    # Recalculate overlap without seeds
    module_map_no_seeds = {
        k: v for k, v in module_map_no_seeds.items() if v
    }  # filter empty modules, after seed removal

    # Only proceed if there are modules left after removing seeds
    if module_map_no_seeds:
        ids_no_seeds, modules_no_seeds = zip(*sorted(module_map_no_seeds.items()))
        jaccard_no_seeds_df = pairwise_matrix(modules_no_seeds, ids_no_seeds, jaccard)
        jaccard_no_seeds_df.to_csv(
            "jaccard_similarity_no_seeds_matrix_mqc.tsv", sep="\t"
        )

        shared_nodes_no_seeds_df = pairwise_matrix(
            modules_no_seeds, ids_no_seeds, shared_nodes
        )
        shared_nodes_no_seeds_df.to_csv(
            "shared_nodes_no_seeds_matrix_mqc.tsv", sep="\t"
        )


if __name__ == "__main__":
    sys.exit(main())
