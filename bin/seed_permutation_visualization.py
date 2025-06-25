#!/usr/bin/env python

import argparse
import logging
import sys
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import matplotlib.colors as mcolors
import numpy as np

logger = logging.getLogger()


def parse_args(argv=None):
    """Define and immediately parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Calculate overlap matrices",
        epilog="Example: python seed_permutation_visualization.py --seed_ids seed_id_1 seed_id_2 --network_ids network_id_1 network_id_2 --amim_ids amim_id1 amim_id2 --inputs file1 file2",
    )
    parser.add_argument(
        "--seed-ids",
        type=str,
        help="IDs of the used seed sets.",
        nargs="+",
        required=True,
    )
    parser.add_argument(
        "--network-ids",
        type=str,
        help="IDs of the networks used for the modules.",
        nargs="+",
        required=True,
    )
    parser.add_argument(
        "--amim-ids",
        type=str,
        help="IDs for the methods used to generate the modules.",
        nargs="+",
        required=True,
    )
    parser.add_argument(
        "--inputs",
        help="A list of TSV files providing seed permutation evaluations.",
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


def plot_dynamic_heatmap(
    data,
    row_height=0.2,
    col_width=1,
    annot=True,
    title="",
    **kwargs,
):
    """
    Plot a heatmap with dynamic figure size based on data shape

    Parameters:
        data (DataFrame or 2D array): Heatmap data.
        row_height (float): Height per row in inches.
        col_width (float): Width per column in inches.
        annot (bool): Whether to annotate cells with their values.
        title (str): Title of the heatmap.
        kwargs: Other keyword arguments passed to sns.heatmap.
    """

    # Calculate figure size based on data shape
    n_rows, n_cols = data.shape
    height = max(6, n_rows * row_height)
    width = max(2, n_cols * col_width)

    # Create the heatmap
    plt.figure(figsize=(width, height))
    ax = sns.heatmap(
        data,
        linecolor="black",
        linewidths=0.5,
        annot=annot,
        **kwargs,
    )
    ax.set_title(title)
    ax.set_xlabel("")
    plt.tight_layout()
    return ax


def main(argv=None):
    """Coordinate argument parsing and program execution."""
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")
    logger.debug(f"{args=}")

    assert (
        len(args.inputs)
        == len(args.seed_ids)
        == len(args.network_ids)
        == len(args.amim_ids)
        == len(args.amim_ids)
    )
    df_list = []
    for input_file, seed_id, network_id, amim_id in zip(
        args.inputs, args.seed_ids, args.network_ids, args.amim_ids
    ):
        df = pd.read_csv(input_file, sep="\t")
        assert set(
            [
                "Removed seeds",
                "Retrieval frequency",
                "Normalized retrieval frequency",
                "Jaccard index",
            ]
        ).issubset(df.columns)
        df["seed_id"] = seed_id
        df["network_id"] = network_id
        df["amim_id"] = amim_id
        df_list.append(df)
    df = pd.concat(df_list, ignore_index=True)

    # Generate a custom colormap (with white at 0 and Reds for other values)
    # Start with the Reds colormap
    reds = plt.get_cmap("Reds")

    # Create a new colormap that maps 0 to white
    new_colors = reds(np.linspace(0, 1, 256))
    new_colors[0] = [1, 1, 1, 1]  # RGBA for white

    # Create the new colormap
    white_to_reds = mcolors.ListedColormap(new_colors)

    grouped_dfs = [
        (group, data) for group, data in df.groupby(["seed_id", "network_id"])
    ]

    # Create heatmaps for seed rediscovery
    for group in grouped_dfs:
        seed_id = group[0][0]
        network_id = group[0][1]
        output_prefix = f"{seed_id}.{network_id}.seed_rediscovery"
        group_df = group[1]
        group_df = group_df.pivot(
            index="Removed seeds", columns="amim_id", values="Retrieval frequency"
        )
        # sort rows by sum of values
        group_df = group_df.loc[group_df.sum(axis=1).sort_values(ascending=False).index]
        # sort columns by sum of values
        group_df = group_df[group_df.sum(axis=0).sort_values(ascending=False).index]
        # save grouped data to a TSV file
        group_df.to_csv(f"{output_prefix}.tsv", sep="\t", index=False, header=True)

        ax = plot_dynamic_heatmap(
            group_df,
            title="Seed rediscovery",
            cbar=False,
            cmap=white_to_reds,
            vmin=0,
            vmax=1,
        )

        # save the heatmap
        plt.savefig(f"{output_prefix}.png", dpi=300, bbox_inches="tight")
        plt.savefig(f"{output_prefix}.pdf", dpi=300, bbox_inches="tight")
        plt.close()

    # Create heatmaps for robustness
    for group in grouped_dfs:
        seed_id = group[0][0]
        network_id = group[0][1]
        output_prefix = f"{seed_id}.{network_id}.robustness"
        group_df = group[1]
        group_df = group_df.pivot(
            index="Removed seeds", columns="amim_id", values="Jaccard index"
        )
        # sort rows by sum of values
        group_df = group_df.loc[group_df.sum(axis=1).sort_values(ascending=False).index]
        # sort columns by sum of values
        group_df = group_df[group_df.sum(axis=0).sort_values(ascending=False).index]
        # save grouped data to a TSV file
        group_df.to_csv(f"{output_prefix}.tsv", sep="\t", index=False, header=True)

        ax = plot_dynamic_heatmap(
            group_df,
            title="Robustness",
            cbar=True,
            cbar_kws={"label": "Jaccard index"},
            cmap="mako",
            vmin=0,
            vmax=1,
        )

        # save the heatmap
        plt.savefig(f"{output_prefix}.png", dpi=300, bbox_inches="tight")
        plt.savefig(f"{output_prefix}.pdf", dpi=300, bbox_inches="tight")
        plt.close()


if __name__ == "__main__":
    sys.exit(main())
