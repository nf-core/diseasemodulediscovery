#!/usr/bin/env python
import argparse
from pathlib import Path
import yaml
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
        header_data = yaml.safe_load(header)
        header_id = header_data.get("id", "")

    if header_id == "network_node_degree_distribution":
        save_node_degree_distribution(input_files, header_file)


def save_node_degree_distribution(input_files, header_file):
    with open(header_file, "r", encoding="utf-8") as header:
        mqc_payload = yaml.safe_load(header) or {}

    absolute_data = {}
    relative_data = {}

    for file in input_files:
        with open(file, "r", encoding="utf-8") as distribution_file:
            distribution = yaml.safe_load(distribution_file) or {}

        network_name = distribution.get("name") or file.stem
        absolute = distribution.get("absolute")
        relative = distribution.get("relative")

        if absolute is None or relative is None:
            raise ValueError(
                f"Invalid distribution YAML in {file}: expected keys 'absolute' and 'relative'"
            )

        absolute_data[network_name] = absolute
        relative_data[network_name] = relative

    mqc_payload["data"] = [absolute_data, relative_data]

    with open("./node_degree_distribution_mqc.yaml", "w", encoding="utf-8") as file:
        yaml.safe_dump(mqc_payload, file, sort_keys=False,  default_flow_style=None)


def main():
    args = parse_args()
    parse_input(args.input, args.header)


if __name__ == "__main__":
    sys.exit(main())
