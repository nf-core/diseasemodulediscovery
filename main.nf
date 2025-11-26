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
        ch_seeds,
        ch_network,
        ch_shortest_paths,
        ch_perturbed_networks
    )
    ch_versions = ch_versions.mix(DISEASEMODULEDISCOVERY.out.versions)

    emit:
    multiqc_report                  = DISEASEMODULEDISCOVERY.out.multiqc_report // channel: /path/to/multiqc_report.html
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
        params.input,
        params.help,
        params.help_full,
        params.show_hidden,
        params.seeds,
        params.network,
        params.shortest_paths,
        params.perturbed_networks,
        params.id_space
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
        params.hook_url,
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
