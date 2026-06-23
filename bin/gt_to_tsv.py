#!/usr/bin/env python

from graph_tool.all import *
import sys
import argparse


def gt_to_tsv(input_file, output_file, exclude_seeds=False):

    graph = load_graph(input_file)

    name_property = graph.vertex_properties["name"]

    if exclude_seeds and "is_seed" not in graph.vertex_properties:
        return

    is_seed_property = graph.vertex_properties["is_seed"] if exclude_seeds else None

    with open(output_file, "w") as output_file:
        output_file.write("gene_id\n")

        for vertex in graph.vertices():
            if exclude_seeds and is_seed_property[vertex]:
                continue
            gene_name = name_property[vertex]
            output_file.write(f"{gene_name}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process GT file and generate TSV.")
    parser.add_argument("--input", required=True, help="Input GT file path")
    parser.add_argument("--output", required=True, help="Output TSV file path")
    parser.add_argument(
        "--exclude_seeds", action="store_true", help="Exclude seed nodes from output"
    )

    args = parser.parse_args()

    gt_to_tsv(args.input, args.output, exclude_seeds=args.exclude_seeds)
