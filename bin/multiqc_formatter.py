#!/usr/bin/env python
import argparse
import graph_tool.all as gt
from graph_tool_parser import load
from pathlib import Path
from collections import Counter
import sys


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description="formats file for multiqc custom contents",
        epilog="Example: python multiqc_formatter.py -i network.gt -f network_degree",
    )
    parser.add_argument(
        "-i", "--input", type=Path, nargs="*", required=True, help="Input files"
    )
    parser.add_argument("-H", "--header", type=Path, required=True, help="Header file")
    return parser.parse_args(argv)


def parse_input(input_files, header_file):
    with open(header_file, "r") as header:
        header_id = header.readline().split(":", 1)[1].strip()

    if header_id == "network_node_degree_distribution":
        save_node_degree_distribution(input_files, header_file)


def save_node_degree_distribution(input_files, header_file):
    with open(header_file, "r") as header:
        network_degree_header = header.read()

    network_data = []
    for file in input_files:
        g = load(file_in=file, extension=file.suffix)
        network_name = file.stem
        # Calculate degree for each vertex
        degrees = [v.out_degree() for v in g.vertices()]
        # Count frequency of each degree
        degree_counts = Counter(degrees)

        # Get total number of vertices for normalization
        total_vertices = len(degrees)

        # Create absolute counts: [[degree, count], ...]
        absolute_counts = [
            [degree, count] for degree, count in sorted(degree_counts.items())
        ]

        # Create relative frequencies: [[degree, fraction], ...]
        relative_frequencies = [
            [degree, count / total_vertices]
            for degree, count in sorted(degree_counts.items())
        ]

        network_data.append(
            {
                "name": network_name,
                "absolute": absolute_counts,
                "relative": relative_frequencies,
            }
        )

    with open("./node_degree_distribution_mqc.yaml", "w") as file:
        file.write(network_degree_header)
        file.write("  - ")
        first = True
        for network in network_data:
            if first:
                file.write(f"{network['name']}:\n")
                first = False
            else:
                file.write(f"    {network['name']}:\n")
            for degree, count in network["absolute"]:
                file.write(f"      - [{degree}, {count}]\n")
        file.write("\n")
        file.write("  - ")
        first = True
        for network in network_data:
            if first:
                file.write(f"{network['name']}:\n")
                first = False
            else:
                file.write(f"    {network['name']}:\n")
            for degree, fraction in network["relative"]:
                file.write(f"      - [{degree}, {fraction}]\n")


def main():
    args = parse_args()
    parse_input(args.input, args.header)


if __name__ == "__main__":
    sys.exit(main())
