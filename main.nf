#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/diseasemodulediscovery
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/diseasemodulediscovery
    Website: https://nf-co.re/diseasemodulediscovery
    Slack  : https://nfcore.slack.com/channels/diseasemodulediscovery
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { DISEASEMODULEDISCOVERY  } from './workflows/diseasemodulediscovery'
include { PIPELINE_INITIALISATION } from './subworkflows/local/utils_nfcore_diseasemodulediscovery_pipeline'
include { PIPELINE_COMPLETION     } from './subworkflows/local/utils_nfcore_diseasemodulediscovery_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Run main analysis pipeline depending on type of input
//
workflow NFCORE_DISEASEMODULEDISCOVERY {

    take:
    ch_seeds                // channel: [ val(meta[id,seeds_id,network_id]), path(seeds) ]
    ch_network              // channel: [ val(meta[id,network_id]), path(network) ]
    ch_shortest_paths       // channel: [ val(meta[id,network_id]), path(shortest_paths) ]
    ch_perturbed_networks    // channel: [ val(meta[id,network_id]), [path(perturbed_networks)] ]

    main:

    ch_versions = Channel.empty()

    //
    // WORKFLOW: Run pipeline
    //

    DISEASEMODULEDISCOVERY (
        params.multiqc_config,
        params.multiqc_logo,
        params.multiqc_methods_description,
        params.outdir,
        ch_seeds,
        ch_network,
        ch_shortest_paths,
        ch_perturbed_networks
    )
    ch_versions = ch_versions.mix(DISEASEMODULEDISCOVERY.out.versions)

    emit:
    seeds_empty_status              = DISEASEMODULEDISCOVERY.out.seeds_empty_status             // channel: [id, boolean]
    module_empty_status             = DISEASEMODULEDISCOVERY.out.module_empty_status           // channel: [id, boolean]
    visualization_skipped_status    = DISEASEMODULEDISCOVERY.out.visualization_skipped_status  // channel: [id, boolean]
    drugstone_skipped_status        = DISEASEMODULEDISCOVERY.out.drugstone_skipped_status      // channel: [id, boolean]
    multiqc_report                  = DISEASEMODULEDISCOVERY.out.multiqc_report                // channel: /path/to/multiqc_report.html
    versions                        = ch_versions                                       // channel: [version1, version2, ...]

}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

params {

    //
    // Input options
    //
    // Path to a CSV sample sheet defining seed file-network combinations
    input: String?

    // Path(s) to one or multiple file(s) with seed genes
    seeds: String?

    // Path(s) to one or multiple PPI network(s) in gt, csv, tsv, graphml, xml, dot, or gml format.
    network: String?

    // Set a custom repository link for the prepared networks.
    prepared_networks_url: String = 'https://zenodo.org/records/18702264/files/'

    //
    // Network expansion
    //
    // Flag for skipping first neighbor
    skip_firstneighbor: Boolean

    // Flag for skipping DOMINO
    skip_domino: Boolean

    // Flag for skipping Robust
    skip_robust: Boolean

    // Flag for skipping Robust (bias-aware)
    skip_robust_bias_aware: Boolean

    // Flag for skipping DIAMOnD
    skip_diamond: Boolean

    // Desired number of DIAMOnD genes.
    diamond_n: Integer = 200

    // Weight of the seeds.
    diamond_alpha: Integer = 1

    // Flag for skipping random walk with restart
    skip_rwr: Boolean

    // Add a scaling depending on the node's degree.
    rwr_scaling: Boolean

    // Compute the symmetric instead of column-wise normalized Markov matrix.
    rwr_symmetrical: Boolean

    // Damping factor/restart probability.
    rwr_r: Float = 0.8

    //
    // Visualization
    //
    // Skip module visualization
    skip_visualization: Boolean

    // If a module has more nodes it will not be visualized.
    visualization_max_nodes: Integer = 500

    // Flag for skipping the export to the Drugst.One platform
    skip_drugstone_export: Boolean

    // If a module has more nodes it will not be exported to the Drugst.One platform. Includes drug prioritization.
    drugstone_max_nodes: Integer = 500

    //
    // Annotation
    //
    // Flag for skipping the annotation part of the process.
    skip_annotation: Boolean

    // Type of gene/protein ids
    id_space: String = 'entrez'

    // Flag for validating online at baderlab.org.
    validate_online: Boolean

    // Flag for adding variants to the biopax annotation file.
    add_variants: Boolean

    //
    // Evaluation
    //
    // Flag skipping the entire evaluation workflow
    skip_evaluation: Boolean

    // Flag for skipping g:Profiler
    skip_gprofiler: Boolean

    // Flag for skipping DIGEST
    skip_digest: Boolean

    // Flag for skipping only the reference-free mode of DIGEST
    skip_digest_reference_free: Boolean

    // Flag for skipping only the reference-based mode of DIGEST
    skip_digest_reference_based: Boolean

    // Flag for running the seed perturbation-based evaluation
    run_seed_perturbation: Boolean

    // Flag for running the network perturbation-base evaluation
    run_network_perturbation: Boolean

    // Number of times the network will be perturbed for the network perturbation-based evaluation
    n_network_perturbations: Integer = 100

    // Path(s) to folder(s) with pre-computed perturbed networks for the network perturbation-based evaluation
    perturbed_networks: String?

    //
    // Drug prioritization
    //
    // Flag for running proximity
    run_proximity: Boolean

    // Path(s) to the shortest path pickle file(s) used for proximity.
    shortest_paths: String?

    // Local path to the drug to targets file used for proximity.
    drug_to_target: String?

    // Flag for skipping drug predictions
    skip_drug_predictions: Boolean

    // Drugst.One parameter for including indirect drugs.
    includeIndirectDrugs: Boolean

    // Drugst.One parameter for including non approved drugs.
    includeNonApprovedDrugs: Boolean

    // Drugst.One parameter for defining  the maximum number of returned drugs.
    result_size: Integer = 50

    // Drugst.One parameter for algorithms to be used. Comma separated list. Options: 'trustrank', 'degree' and 'closeness'.
    drugstone_algorithms: String = 'trustrank'

    //
    // MultiQC options
    //
    // Custom config file to supply to MultiQC.
    multiqc_config: String?

    // MultiQC report title. Printed as page header, used for filename if not otherwise specified.
    multiqc_title: String?

    // Custom logo file to supply to MultiQC. File name must also be set in the MultiQC config file
    multiqc_logo: String?

    // File size limit when attaching MultiQC reports to summary emails.
    max_multiqc_email_size: String = '25.MB'

    // Custom MultiQC yaml file containing HTML including a methods description.
    multiqc_methods_description: String?

    //
    // Boilerplate options
    //
    // Email address for completion summary.
    email: String?

    // Email address for completion summary, only when pipeline fails.
    email_on_fail: String?

    // Send plain-text email instead of HTML.
    plaintext_email: Boolean

    // Display the help message.
    help: Boolean

    // Display the full detailed help message.
    help_full: Boolean

    // Display hidden parameters in the help message (only works when --help or --help_full are provided).
    show_hidden: Boolean

    // Display version and exit.
    version: Boolean

    //
    // Schema validation default options
    //
    // Boolean whether to validate parameters against the schema at runtime
    validate_params: Boolean = true
}

workflow {

    main:
    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        params.help,
        params.help_full,
        params.show_hidden,
    )

    //
    // WORKFLOW: Run main workflow
    //
    NFCORE_DISEASEMODULEDISCOVERY (PIPELINE_INITIALISATION.out.seeds, PIPELINE_INITIALISATION.out.network, PIPELINE_INITIALISATION.out.shortest_paths, PIPELINE_INITIALISATION.out.perturbed_networks)

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        NFCORE_DISEASEMODULEDISCOVERY.out.multiqc_report,
        NFCORE_DISEASEMODULEDISCOVERY.out.seeds_empty_status,
        NFCORE_DISEASEMODULEDISCOVERY.out.module_empty_status,
        NFCORE_DISEASEMODULEDISCOVERY.out.visualization_skipped_status,
        NFCORE_DISEASEMODULEDISCOVERY.out.drugstone_skipped_status
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
