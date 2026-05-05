# nf-core/diseasemodulediscovery: Output

## Introduction

This document describes the output produced by the pipeline. Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline.

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

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
  - [ROBUST (bias-aware)](#robust-bias-aware)
  - [RWR](#rwr)
  - [1st Neighbors](#1st-neighbors)
- [Disease module evaluation](#disease-module-evaluation)
  - [g:Profiler](#gprofiler)
  - [DIGEST](#digest)
  - [Network topology](#topology)
  - [Overlap](#overlap)
  - [Seed perturbation](#seed-perturbation)
  - [Network perturbation](#network-perturbation)
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
  - `<network>.robust.tsv`: Input network in the format required for ROBUST or ROBUST (bias-aware). Only created if the methods are used.
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

[DIAMOnD](https://github.com/dinaghiassian/DIAMOnD) iteratively expands the initial set of seed nodes by adding one node at a time. At each step, the algorithm selects the node with the highest connectivity significance to the current seed set, as determined by a hypergeometric test. This process continues until a predefined number of nodes have been incorporated. DIAMOnD returns only the nodes added to the module, so the pipeline appends the original seed nodes to the module at the end. Each node is annotated with the order in which it was added (`rank`) and the corresponding hypergeometric test p-value (`p_hyper`). Both values are 0 for seed nodes.

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

### ROBUST (bias-aware)

[ROBUST (bias-aware)](https://github.com/bionetslab/robust_bias_aware) follows the same strategy as [ROBUST](#robust) but increases edge costs for nodes that are frequently used as baits in PPI detection experiments. This penalization helps to mitigate study bias present in current PPI networks. The added node annotations are the same as for ROBUST.

<details markdown="1">
<summary>Output files</summary>

- `modules/{gt,graphml,tsv_nodes,tsv_edges}/`
  - `<seeds>.<network>.robust_bias_aware.{gt,grahml,nodes.tsv,edges.tsv}`: ROBUST (bias-aware) module in different formats.

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

[g:Profiler](https://biit.cs.ut.ee/gprofiler/gost) is used via the R package [gprofiler2](https://cran.r-project.org/web/packages/gprofiler2/index.html) to perform over-representation analysis (ORA), i.e., to find gene sets of pathways in which the module nodes are enriched. For this, the module nodes are used as foreground, and all nodes of the corresponding input network as background.

<details markdown="1">
<summary>Output files</summary>

Output file documentation is based on the nf-core module [gprofiler2_gost](https://nf-co.re/modules/gprofiler2_gost/).

- `evaluation/gprofiler/<seeds>.<network>.<amim>/`
  - `<seeds>.<network>.<amim>.gprofiler2.all_enriched_pathways.tsv`: Table listing all enriched pathways that were found.
  - `<seeds>.<network>.<amim>.gprofiler2.gostplot.html`: Interactive Manhattan plot of all enriched pathways.
  - `<seeds>.<network>.<amim>.gprofiler2.gostplot.png`: Manhattan plot of all enriched pathways.
  - `<seeds>.<network>.<amim>.gprofiler2.gost_results.rds`: R object containing the results of the gost query.
  - `<seeds>.<network>.<amim>.gprofiler2.<source>.sub_enriched_pathways.tsv`: Table listing enriched pathways that were found from one particular source.
  - `<seeds>.<network>.<amim>.gprofiler2.<source>.sub_enriched_pathways.png`: Bar plot showing the fraction of genes that were found enriched in each pathway.
  - `*ENSG_filtered.gmt`: GMT file that was provided as input or that was downloaded from g:profiler if no input GMT file was given; filtered for the selected datasources.
  - `R_sessionInfo.log`: Log file containing information about the R session that was run for this module.

</details>

### DIGEST

[DIGEST](https://github.com/bionetslab/digest) is a tool designed to evaluate the functional coherence of disease modules. It assumes that genes within a module should participate in related biological processes, as indicated by annotations from Gene Ontology (GO) — including Biological Process (GO.BP), Cellular Component (GO.CC), and Molecular Function (GO.MF) — as well as from KEGG pathways.

DIGEST is executed in two modes:

- Reference-free mode (`subnetwork`) – evaluates the functional coherence among all genes in the module.
- Reference-based mode (`subnetwork-set`) – compares the coherence of the original seed genes with the genes added during module expansion.

Both modes use Jaccard similarity to measure functional overlap and generate 1,000 random modules from the input network(s) to perform perturbation-based significance testing. The resulting empirical p-values are summarized in the MultiQC report.

<details markdown="1">
<summary>Output files</summary>

- `evaluation/digest/{reference-free,reference-based}/<seeds>.<network>.<amim>/`
  - `<seeds>.<network>.<amim>_JI-based_p-value.png`: Scatter plot visualizing the empirical functional coherence p-values.
  - `<seeds>.<network>.<amim>_p-value_validation.csv`: Table with empirical functional coherence p-values for each gene set/pathway source.
  - `<seeds>.<network>.<amim>_input_validation.csv`: Table with the functional coherence scores.
  - `<seeds>.<network>.<amim>_result.json`: Full results as JSON file.
  - `<seeds>.<network>.<amim>_<source>_annotation_distribution.png`: Histogram showing the distribution of the number of associated gene sets/pathways for each query node.
  - `<seeds>.<network>.<amim>_<source>_sankey.png`: Sankey plot showing the top 10 most frequent gene sets/pathways linked to the query nodes.
  - `<seeds>.<network>.<amim>_JI-based_<source>_distribution.png`: Histogram of the distribution of the functional coherence score based on randomized data. The functional coherence score of the input is marked through a red vertical line.
  - `<seeds>.<network>.<amim>_mappability.png`: Bar plot showing the fraction of query nodes that were mappable to the different gene set/pathway sources.

- `mqc_summaries/`
  - `digest_{reference-free,reference-based}_mqc.tsv`: Summary of the empirical functional coherence p-values for the MultiQC report.
  </details>

### Network topology

The [graph-tool](https://graph-tool.skewed.de/) library is used to compute summary statistics describing the topology of the disease modules. These include the number of nodes and edges, the count of the included seed nodes, the [diameter](https://graph-tool.skewed.de/static/docs/stable/autosummary/graph_tool.topology.pseudo_diameter.html#graph_tool.topology.pseudo_diameter), the number of connected components, the size of the largest component, the number of isolated nodes (nodes without edges), and the maximum shortest-path distance from any added node to its nearest seed node. These statistics are summarized in the `General Statistics` section of the MultiQC report.

<details markdown="1">
<summary>Output files</summary>

- `mqc_summaries/`
  - `topology_mqc.tsv`: Network topology measures of the disease modules for the MultiQC report.

  </details>

### Overlap

The pipeline calculates pairwise overlaps between the node sets of all modules to assess similarities between different seed sets, networks, or methods. For each pair of modules, it reports both the number of shared nodes between their node sets (`A ∩ B`) and their Jaccard similarity (`|A ∩ B| / |A ∪ B|`). To specifically assess similarities among the added nodes, the same measures are also computed on the sets `A \ S` and `B \ S`, where `S` denotes the set of seed nodes. The overlaps are visualized as heatmaps in the MultiQC report.

<details markdown="1">
<summary>Output files</summary>

- `mqc_summaries/`
  - `jaccard_similarity_matrix_mqc.tsv`: Pairwise Jaccard similarities between the node sets of the disease modules for the MultiQC report.
  - `jaccard_similarity_no_seeds_matrix_mqc.tsv`: Pairwise Jaccard similarities between the node sets of the disease modules for the MultiQC report, excluding the seed nodes for the calculation.
  - `shared_nodes_matrix_mqc.tsv`: Pairwise counts of shared nodes between the node sets of the disease modules are for the MultiQC report.
  - `shared_nodes_no_seeds_matrix_mqc.tsv`: Pairwise counts of shared nodes between the node sets of the disease modules are for the MultiQC report, excluding the seed nodes for the calculation.

  </details>

### Seed perturbation

If provided with the `--run_seed_perturbation` parameter, the pipeline runs a leave-one-out analysis to check how robust a module discovery method is against small changes in the seed set and to calculate a rediscovery rate. Starting with the original seed set, the pipeline creates new versions of the set by leaving out one seed at a time. For each of these perturbed seed sets, a new disease module is inferred using the same method.

#### Robustness

Each perturbed module is compared to the original module to see how similar they are, using the Jaccard index (`|A ∩ B| / |A ∪ B|`) of the node sets. The higher the Jaccard similarities, the more robust the module is to small input perturbations.

The corresponding distribution, as well as its mean value, is part of the MultiQC report.

#### Rediscovery rate

This procedure also allows calculation of a seed rediscovery rate — the likelihood that a left-out seed is added back into the resulting module. This metric reflects how well the method can recover disease-associated genes or proteins that were not provided in the input. On the other hand, if the rediscovery rate is consistently low across different methods, it may indicate that the left-out seed has weak or uncertain relevance.

Because larger modules are more likely to include an omitted seed by chance, the normalized rediscovery rate is adjusted for module size, i.e., divided by the number of nodes in the original module. This makes the rediscovery measure fairer and easier to compare across different modules.

Both normalized and raw rediscovery rates are summarized in the `General Statistics` section of the MultiQC report.

<details markdown="1">
<summary>Output files</summary>

- `evaluation/seed_perturbation/<seeds>.<network>.<amim>/`
  - `<seeds>.<network>.<amim>.seed_perturbation_evaluation_summary.tsv`: Leave-one-out analysis results aggregated across all iterations. Includes the mean Jaccard index, raw rediscovery rate, and normalized rediscovery rate.
  - `<seeds>.<network>.<amim>.seed_perturbation_evaluation_detailed.tsv`: Leave-one-out analysis results on the level of individual iterations. Includes the mean Jaccard index, raw rediscovery rate, and normalized rediscovery rate.

- `evaluation/seed_perturbation/`
  - `<seeds>.<network>.robustness.{png,pdf}`: Heatmap visualizing the robustness (indicated through the Jaccard index) of different AMIMs on the level of individual seed nodes. Rows are sorted by the row sum, columns are sorted by the column sum.
  - `<seeds>.<network>.robustness.tsv`: Table reporting the robustness (indicated through the Jaccard index) of different AMIMs on the level of individual seed nodes.
  - `<seeds>.<network>.seed_rediscovery.{png,pdf}`: Heatmap visualizing whether different AMIMs were able to recover individual seeds. Rows are sorted by the row sum, columns are sorted by the column sum.
  - `<seeds>.<network>.seed_rediscovery.tsv`: Table reporting whether different AMIMs were able to recover individual seeds.

- `mqc_summaries/`
  - `seed_perturbation_mqc.tsv`: Summaries of the mean Jaccard index, raw rediscovery rate, and normalized rediscovery rate for the MultiQC report.
  - `seed_perturbation_jaccard_mqc.yaml`: Jaccard index distributions for the MultiQC report.

  </details>

### Network perturbation

Use the `--run_network_perturbation` option to repeatedly rewire the edges of the input network while preserving each node’s degree. The pipeline then reruns the module identification methods on these perturbed networks.

The network rewiring is performed using the [graph-tool](https://graph-tool.skewed.de/) function [`random_rewire`](https://graph-tool.skewed.de/static/docs/stable/autosummary/graph_tool.generation.random_rewire.html) with `"constrained-configuration"` as model and 100 full sweeps over all edges.

If the resulting modules are similar to those from the original network (indicated through a high Jaccard index), this indicates that the methods rely mainly on node degree rather than on the specific edge connections.

The corresponding distribution, as well as its mean value, is part of the MultiQC report.

<details markdown="1">
<summary>Output files</summary>

- `mqc_summaries/`
  - `network_perturbation_mqc.tsv`: Summaries of the mean Jaccard index for the MultiQC report.
  - `network_perturbation_jaccard_mqc.yaml`: Jaccard index distributions for the MultiQC report.

- `input/perturbed_networks/<network>/`
  - `<network>.*.gt`: The rewired networks. Can be reused for repeated analyses.

  </details>

## Drug prioritization

### Drugst.One

The [Drugst.One Python package](https://github.com/drugst-one/python-package) identifies potential drug candidates targeting nodes in the disease modules. To prioritize these compounds, different algorithms are available:

- Degree centrality – ranks compounds by the number of module nodes they target.
- Harmonic centrality – considers the average shortest path from each compound to all module nodes.
- TrustRank – uses network propagation to rank compounds based on their relevance within the network.

More details on these algorithms are available in the [supplementary material of the Drugst.One publication](https://oup.silverchair-cdn.com/oup/backfile/Content_public/Journal/nar/52/W1/10.1093_nar_gkae388/1/gkae388_supplemental_file.pdf?Expires=1758252323&Signature=w75gGflGquYhahJdf6tLUUdy~NviTBrSrgcu-qeLvQ4~7ZW4gFMzpC~4Os7TnIvCyMfSKUgVTCGdswYv8xk6dQDXXqP-3LJTk1dE25BGibMX2eDgok2T1cTz8X078xkzrueyF-F2MBtD5hpPNPpu704o2DMJLVxL-olWbDkulCeLj8KCz29GOLZjUd7fg39zgU7O1IYJFtYFL2NDydGzDgZ8NjG6SozGC9H0OIVc6IHCiyvdzqG4dlb6NvsphhX3NUkqAXp1QqlNhXKZPJ6uWtkVDUgIYLrRgkK8V11JxtDPJpwBalzU9~wn0fP0cMpdZhU5vrVrHSnqTVNU~xcjrg__&Key-Pair-Id=APKAIE5G5CRDK6RD3PGA).

<details markdown="1">
<summary>Output files</summary>

- `drug_prioritization/drugstone/`
  - `<seeds>.<network>.<amim>.<drug_algorithm>.drug_predictions.tsv`: Table containing disease module node annotations merged with the drug-prioritization results. The first columns correspond to the existing disease module node annotations. Additional columns indicate the prioritized compounds through their [DrugBank](https://go.drugbank.com/) ID (`drug_id`), a prioritization `score` depending on the used algorithm, and the name of the compound (`drug_name`). If a single module node is targeted by multiple compounds,
  - `<seeds>.<network>.<amim>.<drug_algorithm>.csv`: Table containing the raw Drugst.One request results.

  </details>

## Other

### Drugst.One export

The MultiQC report lists export links for each disease module to visualize and manipulate them directly through the [Drugst.One web interface](https://drugst.one/home).

<details markdown="1">
<summary>Output files</summary>

- `mqc_summaries/`
  - `drugstone_link_mqc.tsv`: Table with export links for the MultiQC report.

  </details>

### Network visualization

Visual network representations of the inferred modules — both with and without assigned drugs — are generated using the [graph-tool](https://graph-tool.skewed.de/static/docs/stable/draw.html) package and are available in PNG, SVG, and PDF formats. Additionally, interactive HTML visualizations are produced using the [pyvis](https://github.com/WestHealth/pyvis) package. Coloring distinguishes seed nodes from the added module nodes.

<details markdown="1">
<summary>Output files</summary>

- `results/modules_visualized/{html,pdf,svg,png}/`
  - `<seeds>.<network>.<amim>.{html,pdf,svg,png}`: Network visualizations of the disease modules in different formats.

- `results/modules_visualized_with_drugs/{html,pdf,svg,png}/`
  - `<seeds>.<network>.<amim>.{html,pdf,svg,png}`: Network visualizations of the disease modules in different formats, including drug nodes. It will only be generated if drug prioritization was performed.

</details>

### Annotation

The disease modules are annotated with supplementary biological information queried from [NeDRex database](https://nedrex.net/).
The annotated modules are saved using [BioPax](http://www.biopax.org/release/biopax-level3-documentation.pdf), short for Biological Pathway Exchange. BioPax is a standard language and format for representing biological pathway knowledge. The format of the files is validated using the [BioPax Validator](https://github.com/BioPAX/validator).

The resulting files have the following structure:

**Entities**

- Proteins with UnificationXref and ProteinReference
- Genes with UnificationXref
- SmallMolecules as drugs with UnificationXref and SmallMoleculeReference

**Relationships**

- Protein encoded by gene as RelationshipXref
- Gene associated with disorder as RelationshipXref
- Drug targets protein as RelationshipXref
- Drug has side effects as RelationshipXref
- Protein is in a cellular component as RelationshipXref

**Interactions**

- Protein interactions as MolecularInteraction

> [!NOTE]
> If the network hands over UniProt-IDs, only those are used and mapped to the encoding genes. If Entrez-IDs are given, all encoded proteins by those genes are considered.

<details markdown="1">
<summary>Output files</summary>

- `modules/biopax/`
  - `<seeds>.<network>.<amim>.owl`: BioPax-files for each module in BioPax-format.

- `reports/`
  - `biopax-validator-report.html`: HTML file with the BioPax-validator results that can be viewed in your web browser.

</details>

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
