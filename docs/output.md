# nf-core/diseasemodulediscovery: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

## File naming

Many output files are named based on the combination of seed file, network file, disease module discovery method, and drug prioritization method used:

- `<seeds>`: The name of the input seed file without the file ending.
- `<network>`: The name of the input network file without the file ending.
- `<amim>`: The name of the disease module discovery method (active module identification method (AMIM)).
- `<drug_algorithm>:`: The name of the drug prioritization algorithm.

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [Input preparation](#input-preparation)
  - [Prepare network](#prepare-network)
  - [Check seed file](#check-seed-file)
- [Disease module inference](#disease-module-inference)
  - [Only seeds](#only-seeds)
  - [DOMINO](#domino)
  - [DIAMOnD](#diamond)
  - [ROBUST](#robust)
  - [ROBUST (bias aware)](#robust-bias-aware)
  - [RWR](#rwr)
  - [1st Neighbors](#1st-neighbors)
- [Disease module evaluation](#disease-module-evaluation)
  - [g:Profiler](#gprofiler)
  - [DIGEST](#digest)
  - [Network topology](#topology)
  - [Overlap](#overlap)
  - [Seed permutation](#seed-permutation)
  - [Network permutation](#network-permutation)
- [Drug prioritization](#drug-prioritization)
  - [Drugst.One](#drugstone)
- [Other](#other)
  - [Drugst.One export](#drugstone-export)
  - [Network visualization](#network-visualization)
  - [Annotation](#annotation)
- [Reporting](#reporting)
  - [MultiQC](#multiqc) - Aggregate report describing results and QC from the whole pipeline
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution

## Input preparation

### Prepare network

The [graph-tool](https://graph-tool.skewed.de/) library is used to parse the input network(s) into the [`.gt`](https://graph-tool.skewed.de/static/docs/stable/gt_format.html) format, the internal representation used for networks within the pipeline. Additionally, it is used to generate networks in the specific formats required by the various disease module inference methods. This step also gathers summary statistics for the MultiQC report, including the number of nodes and edges, the network [diameter](https://graph-tool.skewed.de/static/docs/stable/autosummary/graph_tool.topology.pseudo_diameter.html#graph_tool.topology.pseudo_diameter), the number of connected components, the size of the largest connected component, the count of self-loops (nodes with edges to themselves), and the number of duplicate edges (multiple edges connecting the same two nodes).

<details markdown="1">
<summary>Output files</summary>

- `input/networks/`
  - `<network>.gt`: Parsed input network in `.gt` format.
  - `<network>.domino.sif`: Input network in the format required for DOMINO. Only created if the method is used.
  - `<network>.diamond.csv`: Input network in the format required for DIAMOnD. Only created if the method is used.
  - `<network>.robust.tsv`: Input network in the format required for ROBUST or ROBUST (bias aware). Only created if the methods are used.
  - `<network>.rwr.csv`: Input network in the format required for RWR. Only created if the method is used.
- `mqc_summaries/`
  - ` input_network_mqc.tsv`: Network summary statistics for the MultiQC report.

</details>

### Check seed file

The format of the input seed file(s) is validated, and any seed nodes not present in the corresponding input network are removed. The filtered seed file(s) are then used in subsequent pipeline steps, and a summary of retained and discarded seed nodes is included in the MultiQC report.

<details markdown="1">
<summary>Output files</summary>

- `input/seeds/`
  - `<seeds>.<network>.tsv`: Filtered seed files containing only nodes present in the corresponding network.
  - `<seeds>.<network>.removed.tsv`: The dropped nodes not being present in the corresponding network.
- `mqc_summaries/`
  - ` input_network_mqc.tsv`: Summary about retained and dropped seed nodes for the MultiQC report.

</details>

## Disease module inference

The inferred disease modules are exported in multiple formats, including [`.gt`](https://graph-tool.skewed.de/static/docs/stable/gt_format.html), [`.graphml`](https://de.wikipedia.org/wiki/GraphML), and node and edge lists in `.tsv`. If a method returns only a node list rather than a full network, the connecting edges are extracted from the input network. Module nodes are annotated with their seed status (`is_seed`), their subnetwork participation degree ([`spd`](https://nedrex.net/tutorial/availableFunctions.html)), and a component identifier (`component_id`) to indicate which connected component they belong to. Additionally, tool-specific node properties are added, which are explained in the sections below.

### Only seeds

In addition to the inferred disease modules, the pipeline provides a dummy module inference method that returns only the seed nodes and the edges connecting them in the input network. This serves as a baseline, enabling comparisons between modules containing additional nodes and the core set of seed nodes.

<details markdown="1">
<summary>Output files</summary>

- `modules/{gt,graphml,tsv_nodes,tsv_edges}/`
  - `<seeds>.<network>.no_tool.{gt,grahml,nodes.tsv,edges.tsv}`: Module containing only the seed nodes in different formats.

</details>

### DOMINO

[DOMINO](https://github.com/Shamir-Lab/DOMINO) starts by partitioning the input network into disjoint slices using Louvain clustering. Slices that are enriched for seed nodes, as determined by a hypergeometric test, are selected for further analysis. The selected slices are refined by solving the Prize Collecting Steiner Tree (PCST) problem, and subsequently subdivided into putative modules containing no more than 10 nodes each. Each resulting module is then tested again for seed enrichment using a hypergeometric test. DOMINO can produce multiple non-overlapping modules for a single input seed set. The pipeline reports all modules in a single output file, with individual modules distinguished by the node property `submodule`.

<details markdown="1">
<summary>Output files</summary>

- `modules/{gt,graphml,tsv_nodes,tsv_edges}/`
  - `<seeds>.<network>.domino.{gt,grahml,nodes.tsv,edges.tsv}`: DOMINO module in different formats.

</details>

### DIAMOnD

[DIAMOnD](https://github.com/dinaghiassian/DIAMOnD) iteratively expands the initial set of seed nodes by adding one node at a time. At each step, the algorithm selects the node with the highest connectivity significance to the current seed set, as determined by a hypergeometric test. This process continues until a predefined number of nodes have been incorporated. DIAMOnD itself only return the nodes added to the module, which is why the pipeline adds the seed nodes to the module at the end. DIAMOnD returns only the nodes added to the module, so the pipeline appends the original seed nodes to the module at the end. Each node is annotated with the order in which it was added (`rank`) and the corresponding hypergeometric test p-value (`p_hyper`). Both values are 0 for seed nodes.

<details markdown="1">
<summary>Output files</summary>

- `modules/{gt,graphml,tsv_nodes,tsv_edges}/`
  - `<seeds>.<network>.diamond.{gt,grahml,nodes.tsv,edges.tsv}`: DIAMOnD module in different formats.

</details>

### ROBUST

[ROBUST](https://github.com/bionetslab/robust) repeatedly connects seed nodes by solving the Prize Collecting Steiner Tree (PCST) problem. In each iteration, nodes that were included in previous solutions are penalized, lowering their chance of being selected again. The final disease module consists of nodes that appear in a sufficient number of solutions, enhancing robustness. ROBUST annotates module nodes with a connected component ID (`connected_components_id`), seed status (`isSeed`), the number of solutions the node participated in (`nrOfOccurrences`), the fraction of all solutions the node appeared in (`significance`), and the list of `trees` the node was part of.

<details markdown="1">
<summary>Output files</summary>

- `modules/{gt,graphml,tsv_nodes,tsv_edges}/`
  - `<seeds>.<network>.robust.{gt,grahml,nodes.tsv,edges.tsv}`: ROBUST module in different formats.

</details>

### ROBUST (bias aware)

[ROBUST (bias aware)](https://github.com/bionetslab/robust_bias_aware) follows the same strategy as [ROBUST](#robust) but increases edge costs for nodes that are frequently used as baits in PPI detection experiments. This penalization helps to mitigate study bias present in current PPI networks. The added node annotations are the same as for ROBUST.

<details markdown="1">
<summary>Output files</summary>

- `modules/{gt,graphml,tsv_nodes,tsv_edges}/`
  - `<seeds>.<network>.robust_bias_aware.{gt,grahml,nodes.tsv,edges.tsv}`: ROBUST (bias aware) module in different formats.

</details>

### RWR

<details markdown="1">
<summary>Output files</summary>

- `modules/{gt,graphml,tsv_nodes,tsv_edges}/`
  - `<seeds>.<network>.rwr.{gt,grahml,nodes.tsv,edges.tsv}`: RWR module in different formats.

</details>

### 1st Neighbors

1st Neighbors includes all network nodes that are directly connected to at least one seed node.

<details markdown="1">
<summary>Output files</summary>

- `modules/{gt,graphml,tsv_nodes,tsv_edges}/`
  - `<seeds>.<network>.firstneighbor.{gt,grahml,nodes.tsv,edges.tsv}`: 1st Neighbors module in different formats.

</details>

## Disease module evaluation

### g:Profiler

### DIGEST

### Network topology

### Overlap

### Seed permutation

### Network permutation

## Drug prioritization

### Drugst.One

## Other

### Drugst.One export

### Network visualization

### Annotation

## Reporting

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.

## BioPax

<details markdown="1">
<summary>Output files</summary>

- `biopax/`
  - `*.owl`: BioPax-files for each module in BioPax-format.
  - `biopax-validator-report.html`: a HTML file with the BioPax-validator results that can be viewed in your web browser.

</details>

[BioPax](http://www.biopax.org/release/biopax-level3-documentation.pdf), short for Biological Pathway Exchange,
is a standard language and format for representing biological pathway knowledge. This is how the created .owl files are structured:

### Entities

- Proteins with UnificationXref and ProteinReference
- Genes with UnificationXref
- SmallMolecules as drugs with UnificationXref and SmallMoleculeReference

### Relationships

- Protein encoded by gene as RelationshipXref
- Gene associated with disorder as RelationshipXref
- Drug targets protein as RelationshipXref
- Drug has sideeffect as RelationshipXref
- Protein is in cellular component as RelationshipXref

### Interactions

- Protein interactions as MolecularInteraction

### Notes

If the network hands over uniprot-ids, only those are used and mapped to the encoding genes. If entrez-ids are given, all encoded proteins by those genes are considered.

### Validator

The BioPax-validator validates the created BioPax-files and generates a report in HTML-format in order to check on errors or warnings in the files.

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
