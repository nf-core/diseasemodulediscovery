#!/usr/bin/env python

"""Perturbe a input seed file."""

import argparse
import logging
import sys
import random
from pathlib import Path

logger = logging.getLogger()


def parse_args(argv=None):
    """Define and immediately parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Parse the modules of different tools.",
        epilog="Example: python seed_perturbations.py --seeds seeds.txt",
    )
    parser.add_argument(
        "-s",
        "--seeds",
        help="Path to the seeds file used for module generation.",
        type=Path,
        required=True,
    )
    parser.add_argument(
        "-p",
        "--prefix",
        help="Prefix to name the output files.",
        type=str,
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="The desired log level (default WARNING).",
        choices=("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"),
        default="WARNING",
    )
    parser.add_argument(
        "--random_seed",
        help="The random seed to use for reproducibility (default: 42).",
        type=int,
        default=42,
    )
    parser.add_argument(
        "-x",
        "--num_exclusion",
        help="number of seeds to exclude for leave-x-out perturbation",
        type=int,
        default=3,
    )
    parser.add_argument(
        "-n",
        "--num_permutations",
        help="number of leave-x-out perturbations",
        type=int,
        default=2,
    )

    return parser.parse_args(argv)


def main(argv=None):
    """Coordinate argument parsing and program execution."""
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")
    if not args.seeds.is_file():
        logger.error(f"The given input file {args.seeds} was not found!")
        sys.exit(2)
    logger.debug(f"{args=}")

    path = str(args.seeds)
    stem = Path(path).stem
    extension = Path(path).suffix
    logger.debug(f"{stem=}")
    logger.debug(f"{extension=}")

    # read seed file
    with open(path, "r") as file:
        seeds = [line.strip() for line in file.readlines() if line.strip()]

    # leave one seed out
    for i, seed in enumerate(seeds):
        with open(f"{args.prefix}.perm_{i}{extension}", "w") as file:
            for j, other_seed in enumerate(seeds):
                if not i == j:
                    file.write(f"{other_seed}\n")
    # leave x out
    random.seed(args.random_seed)
    for i in range(args.num_permutations):
        excludes_seeds = random.sample(seeds, args.num_exclusion)
        with open(
            f"{args.prefix}.perm_{i}_x_{args.num_exclusion}{extension}", "w"
        ) as file:
            for seed in seeds:
                if seed not in excludes_seeds:
                    file.write(f"{seed}\n")


if __name__ == "__main__":
    sys.exit(main())
