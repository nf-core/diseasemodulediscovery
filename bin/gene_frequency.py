#!/usr/bin/env python

import argparse
import logging
import sys
from pathlib import Path
import pandas as pd
from graph_tool.all import *
from upsetplot import UpSet
from upsetplot import from_contents
import matplotlib.pyplot as plt
from collections import defaultdict, Counter


logger = logging.getLogger()


def parse_args(argv=None):
    """Define and immediately parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Compute frequency of genes in the modules",
        epilog="Example: python gene_frequency.py --ids id1 id2 --original_modules file1 file2 --permuted_PPI_modules file3 file4 --removed_seed_modules file5 file6",
    )
    parser.add_argument(
        "--ids",
        type=str,
        help="IDs to name the columns/rows of the output matrix",
        nargs="+",
        required=True,
    )
    parser.add_argument(
        "--original_modules",
        help="A list of TSV files providing the original module node lists with at least two columns 'name' and 'is_seed'.",
        type=Path,
        nargs="+",
        required=True,
    )
    parser.add_argument(
        "--permuted_PPI_modules",
        help="A list of GT files providing the list of modules perturbed through PPI randomization.",
        type=Path,
        required=False,
        nargs="+",
    )
    parser.add_argument(
        "--removed_seed_modules",
        help="A list of GT files providing the list of modules perturbed through removal of seed genes.",
        type=Path,
        required=False,
        nargs="+",
    )
    parser.add_argument(
        "-l",
        "--log-level",
        help="The desired log level (default WARNING).",
        choices=("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG"),
        default="WARNING",
    )
    return parser.parse_args(argv)


def frequency_genes_in_original_modules(modules, module_names):
    """
    Given the original modules, return a dictionary mapping each gene to a list of modules in which it appears.

    Input:
        modules: List of original modules (each module is a set of genes).
        module_names: List of names for the original modules.
    Returns:
        dict: {gene: [module1, module2, ...]} where module1, module2 are modules containing the gene.
    """
    gene_dict = defaultdict(list)
    for module, module_name in zip(modules, module_names):
        for gene in module:
            gene_dict[gene].append(module_name)
    
    # sort dictionary with descending frequencies
    sorted_gene_frequency = dict(sorted(gene_dict.items(), key=lambda item: len(item[1]), reverse=True))

    return sorted_gene_frequency


def frequency_genes_in_perturbed_modules(modules, frequency_original_modules):
    """
    Given the perturbed modules, return a dictionary mapping each gene to the frequency of modules in which it appears.

    Input:
        modules: List of perturbed modules (each module is a set of genes).
        frequency_original_modules: Frequency dictionary from original modules.
    Returns:
        dict: {gene: frequency} where frequency is the normalized number of modules containing the gene.
    """
    # gene_counts = defaultdict(int)
    # for module in modules:
    #     for gene in list(frequency_original_modules.keys()):
    #         gene_counts[gene] += 1/len(modules)
    
    gene_counts = Counter()
    for module in modules:
        gene_counts.update(module)

    # Only extract genes that are in the original modules
    d_gene_counts = defaultdict(float)
    for gene in list(frequency_original_modules.keys()):
        try:
            d_gene_counts[gene] = round(gene_counts[gene] / len(modules), 2)
        except Exception:
            d_gene_counts[gene] = 0

    return d_gene_counts


def retrieve_nodes_from_gt_graphs(list_gt_modules):
    """
    Retrieve gene nodes from GT files.
    """
    modules = []
    
    for file in list_gt_modules:
        
        graph = load_graph(file)
        name_property = graph.vertex_properties["name"]
        genes = []
        
        for vertex in graph.vertices():
            gene_name = name_property[vertex]
            genes.append(gene_name)
            
        modules.append(set(genes))
        
    return modules


def main(argv=None):
    """Coordinate argument parsing and program execution."""
    args = parse_args(argv)
    logging.basicConfig(level=args.log_level, format="[%(levelname)s] %(message)s")

    ### COMPUTE FREQUENCIES FOR ORIGINAL MODULES (WITH MODULE NAMES)
    
    # extract data from files
    assert len(args.ids) == len(args.original_modules)
    
    module_map = {}
    for id, file in zip(args.ids, args.original_modules):
        df = pd.read_csv(file, sep="\t")
        
        assert set(["name", "is_seed"]).issubset(df.columns)
        
        module_map[id] = set(df["name"])

    # Sort the module map by ID for consistent output
    module_map = dict(sorted(module_map.items()))
    ids, modules = zip(*module_map.items())
    
    ### CREATE AN UPSET PLOT AND SAVE IT
    
    upset_data = from_contents(module_map)
    plt.figure(figsize=(10, 6))
    UpSet(upset_data, subset_size='count', show_counts=True).plot()
    plt.title("Distribution of Genes in Original Modules")
    plt.savefig("upset_gene_frequency.pdf")
    plt.savefig("upset_gene_frequency.png")
    plt.show()
    
    # Compute frequencies
    gene_frequency_in_modules = frequency_genes_in_original_modules(modules, ids)

    ### COMPUTE FREQUENCIES FOR PERTURBED MODULES
    
    # 1) for permuted PPI modules
    if args.permuted_PPI_modules:
        # extract data from files
        perturbed_ppi_modules = retrieve_nodes_from_gt_graphs(args.permuted_PPI_modules)
        # compute the frequencies
        frequency_permuted_PPI = frequency_genes_in_perturbed_modules(perturbed_ppi_modules, gene_frequency_in_modules)

    # 2) for removed seed modules
    if args.removed_seed_modules:
        # extract data from files
        perturbed_seed_modules = retrieve_nodes_from_gt_graphs(args.removed_seed_modules)
        # compute the frequencies
        frequency_removed_seed = frequency_genes_in_perturbed_modules(perturbed_seed_modules, gene_frequency_in_modules)    


    ### WRITE TSV SUMMARY
    with open("gene_frequency_in_modules.tsv", "w") as f:
        
        if args.permuted_PPI_modules and args.removed_seed_modules:
            f.write("gene\tfrequency in original modules\tfrequency in perturbed modules (network randomization)\tfrequency in perturbed modules (seed removal)\n")
            for gene in gene_frequency_in_modules.keys():
                f.write(f"{gene}\t{gene_frequency_in_modules[gene]}\t{frequency_permuted_PPI[gene]}\t{frequency_removed_seed[gene]}\n")

        elif args.permuted_PPI_modules:
            f.write("gene\tfrequency in original modules\tfrequency in perturbed modules (network randomization)\n")
            for gene in gene_frequency_in_modules.keys():
                f.write(f"{gene}\t{gene_frequency_in_modules[gene]}\t{frequency_permuted_PPI[gene]}\n")
                
        elif args.removed_seed_modules:
            f.write("gene\tfrequency in original modules\tfrequency in perturbed modules (seed removal)\n")
            for gene in gene_frequency_in_modules.keys():
                f.write(f"{gene}\t{gene_frequency_in_modules[gene]}\t{frequency_removed_seed[gene]}\n")

        else:
            f.write("gene\tfrequency in original modules\n")
            for gene in gene_frequency_in_modules.keys():
                f.write(f"{gene}\t{gene_frequency_in_modules[gene]}\n")
                
                
if __name__ == "__main__":
    sys.exit(main())
