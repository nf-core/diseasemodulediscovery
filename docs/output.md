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

### DOMINO

### DIAMOnD

### ROBUST

### ROBUST (bias aware)

### RWR

### 1st Neighbors

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
