#!/usr/bin/env python

import argparse
import os
import logging
import sys
from pathlib import Path
import pandas as pd
from collections import defaultdict, Counter
from upsetplot import UpSet, from_contents
import matplotlib.pyplot as plt
from PIL import Image

logger = logging.getLogger()

def parse_args(argv=None):
    """Define and immediately parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Compute frequency of pathways in the modules",
        epilog="Example: python gene_frequency.py --list_enriched_pathways_kegg file1 file2 --list_enriched_pathways_reactome file3 file4",
    )
    parser.add_argument(
        "--ids",
        type=str,
        help="IDs to name the module expansion algorithms.",
        nargs="+",
        required=True,
    )
    parser.add_argument(
        "--list_enriched_pathways",
        help="A list of TSV files providing the enriched pathways found in each module.",
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

def extract_data(ids, list_enriched_pathways):
    """
    Extract pathway data from a list of enriched pathways files.
    
    Args:
        ids (list): A list of module IDs.
        list_enriched_pathways (list): A list of paths to TSV files containing enriched pathways.

    Returns:
        dict: A dictionary mapping each source of pathways to the dictionary {module ID: set(enriched pathways)}.
    """
    
    unique_sources = []
    
    # create a dictionary {source: {id:set(pathways)}}
    d_source_pathways = defaultdict(lambda: defaultdict(set))
    
    for (id, pathways) in zip(ids, list_enriched_pathways):
        
        df_pathways = pd.read_csv(pathways, sep="\t")

        assert set(["source", "term_name"]).issubset(df_pathways.columns)
        
        # Get the sources
        if len(unique_sources) == 0: 
            unique_sources = df_pathways['source'].unique()

        # Get the pathways for each source and each module 
        for source in unique_sources:
            d_source_pathways[source][id] = set(df_pathways[df_pathways['source'] == source]['term_name'])

    return unique_sources, d_source_pathways


def frequency_pathways_in_modules(ids, list_enriched_pathways):
    """
    Given a list of modules, return a dictionary mapping each pathway to the frequency of modules in which it appears.

    Input:
        modules: List of original modules (each module is a set of genes).
        module_names: List of names for the original modules.
    Returns:
        dict: {gene: [module1, module2, ...]} where module1, module2 are modules containing the gene.
    """
    
    d_pathways = defaultdict(list)
    for id, pathways in zip(ids, list_enriched_pathways):
        for p in pathways:
            d_pathways[p].append(id)

    # sort dictionary with descending frequencies
    sorted_pathway_frequency = dict(sorted(d_pathways.items(), key=lambda item: len(item[1]), reverse=True))

    return sorted_pathway_frequency


def main(argv=None):
    """Coordinate argument parsing and program execution."""
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")

    assert len(args.ids) == len(args.list_enriched_pathways)

    # extract data from files
    unique_sources, d_source_pathways = extract_data(args.ids, args.list_enriched_pathways)

    tmp_files = []
    
    # For each source, create an upset plot, save it in tmp_files, 
    # compute frequencies and create a tsv file
    for i, source in enumerate(unique_sources):
        
        # The values of module_map are the sets of pathways for this source
        module_map = d_source_pathways[source]
        upset_data = from_contents(module_map)
        
        fig = plt.figure(figsize=(8, 6))  # workaround: upset needs a Figure
        upset_plot = UpSet(upset_data, subset_size='count', show_counts=True)
        upset_plot.plot(fig = fig)
        fig.suptitle(f"Distribution of {source} terms in Disease Modules")

        # save the figure for later use
        tmp_file = f"_tmp_upset_{source}.png"
        fig.savefig(tmp_file, dpi=300, bbox_inches='tight')
        tmp_files.append(tmp_file)
        plt.close(fig)  
        
        # Compute frequencies of pathways in modules
        pathway_frequency = frequency_pathways_in_modules(args.ids, module_map.values())

        # write multiqc summary
        with open(f"{source}_terms_frequency_in_modules.tsv", "w") as f:
            f.write("term/pathway\tfrequency in modules\tmodules\n")
            for term, modules in pathway_frequency.items():
                f.write(f"{term}\t{len(modules)}/{len(args.ids)}\t{modules}\n")

    # Save the entire figure with all subplots
    images = [Image.open(f) for f in tmp_files]
    widths, heights = zip(*(img.size for img in images))

    total_height = sum(heights)
    max_width = max(widths)

    combined = Image.new("RGB", (max_width, total_height), "white")

    y_offset = 0
    for img in images:
        combined.paste(img, (0, y_offset))
        y_offset += img.size[1]

    combined.save("upset_pathway_frequency_multiqc.png")
    combined.save("upset_pathway_frequency_multiqc.pdf")

    
    # Cleanup
    for f in tmp_files:
        os.remove(f)


if __name__ == "__main__":
    sys.exit(main())
