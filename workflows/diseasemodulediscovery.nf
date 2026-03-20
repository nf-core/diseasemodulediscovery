/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Loaded from modules/local/
//
include { INPUTCHECK                        } from '../modules/local/inputcheck/main'
include { GRAPHTOOLPARSER                   } from '../modules/local/graphtoolparser/main'
include { NETWORKANNOTATION                 } from '../modules/local/networkannotation/main'
include { SAVEMODULES                       } from '../modules/local/savemodules/main'
include { VISUALIZEMODULES                  } from '../modules/local/visualizemodules/main'
include { VISUALIZEMODULESDRUGS             } from '../modules/local/visualizemodulesdrugs/main'
include { GT2TSV as GT2TSV_Modules          } from '../modules/local/gt2tsv/main'
include { GT2TSV as GT2TSV_Network          } from '../modules/local/gt2tsv/main'
include { DIGEST as DIGEST_REFERENCEFREE    } from '../modules/local/digest/main'
include { DIGEST as DIGEST_REFERENCEBASED   } from '../modules/local/digest/main'
include { MODULEOVERLAP                     } from '../modules/local/moduleoverlap/main'
include { DRUGPREDICTIONS                   } from '../modules/local/drugpredictions/main'
include { TOPOLOGY                          } from '../modules/local/topology/main'
include { DRUGSTONEEXPORT                   } from '../modules/local/drugstoneexport/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { GT_BIOPAX             } from '../subworkflows/local/gt_biopax/main'
include { NETWORKEXPANSION      } from '../subworkflows/local/networkexpansion/main'
include { GT_SEEDPERTURBATION    } from '../subworkflows/local/gt_seedperturbation/main'
include { GT_NETWORKPERTURBATION } from '../subworkflows/local/gt_networkperturbation/main'
include { GT_PROXIMITY          } from '../subworkflows/local/gt_proximity/main'

include { readTsvAsListOfMaps   } from '../subworkflows/local/utils_nfcore_diseasemodulediscovery_pipeline/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//                                                //Evaluation
include { GPROFILER2_GOST        } from '../modules/nf-core/gprofiler2/gost/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_diseasemodulediscovery_pipeline'
include { multiqcTsvFromList     } from '../subworkflows/local/utils_nfcore_diseasemodulediscovery_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Channel guide
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ch_seeds: [ val(meta[id,seeds_id,network_id]), path(seeds) ]
    meta.id:
        - unique identifier for the specific seed file (combination of seeds_id and network_id)
        - used for process tags and output file names
    meta.seeds_id:
        - identifier for the input seed file (network_id not included)
        - used for naming modules (together with meta.id from ch_network)
        - used for merging ch_seeds and ch_modules (only in combination with meta.network_id!)
    meta.network_id:
        - used for merging ch_seeds and ch_network
        - used for merging ch_seeds and ch_modules (only in combination with meta.seeds_id!)
    seeds:
        - path to the seed file

ch_network: [ val(meta[id,network_id]), path(network) ]
    meta.id:
        - unique identifier for the specific network file (network_id)
        - used for process tags and output file names
        - used of naming modules (together with meta.seeds_id from ch_seeds)
    meta.network_id:
        - identifier for the input network file
        - used for merging ch_seeds and ch_network
    network:
        - path to the network file

ch_modules: [ val(meta[id,module_id,amim,seeds_id,network_id]), path(module) ]
    meta.id:
        - unique identifier for the specific module file (combination of seeds_id, network_id, and amim)
        - used for process tags and output file names
    meta.module_id:
        - currently the same as meta.id
    meta.seeds_id:
        - identifier for the input seed file (network_id not included)
        - used for merging ch_modules and ch_seeds (only in combination with meta.network_id!)
    meta.network_id:
        - identifier for the input network file
        - used for merging ch_modules and ch_seeds (only in combination with meta.seeds_id!)
    meta.amim:
        - identifier for the network expansion method
    module:
        - path to the module file

*/


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow DISEASEMODULEDISCOVERY {


    take:
    ch_seeds                // channel: [ val(meta[id,seeds_id,network_id]), path(seeds) ]
    ch_network              // channel: [ val(meta[id,network_id]), path(network) ]
    ch_shortest_paths       // channel: [ val(meta[id,network_id]), path(shortest_paths) ]
    ch_perturbed_networks    // channel: [ val(meta[id,network_id]), [path(perturbed_networks)] ]

    main:

    // Params
    id_space = Channel.value(params.id_space)
    validate_online = Channel.value(params.validate_online)

    if(params.run_proximity){
        proximity_dt = file(params.drug_to_target, checkIfExists:true)
    }

    // Channels
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_seeds_empty_status = Channel.empty()
    ch_module_empty_status = Channel.empty()
    ch_visualization_skipped_status = Channel.empty()
    ch_drugstone_skipped_status = Channel.empty()

    // Run network parser for  networks, supported by graph-tool
    GRAPHTOOLPARSER(ch_network, 'gt')
    ch_versions = ch_versions.mix(GRAPHTOOLPARSER.out.versions)
    ch_network_multiqc = GRAPHTOOLPARSER.out.multiqc
        .map{ meta, path -> path }
        .collectFile(
            cache: false,
            storeDir: "${params.outdir}/mqc_summaries",
            name: 'input_network_mqc.tsv',
            keepHeader: true
        )
    ch_multiqc_files = ch_multiqc_files.mix(ch_network_multiqc)
    ch_network_gt = GRAPHTOOLPARSER.out.network


    // Check input
    // channel: [ val(meta[id,seeds_id,network_id]), path(seeds), path(network) ]
    ch_seeds_network = ch_seeds
        .map{ meta, seeds -> [meta.network_id, meta, seeds]}
        .combine(ch_network_gt.map{meta, network -> [meta.network_id, network]}, by: 0)
        .map{key, meta, seeds, network -> [meta, seeds, network]}

    INPUTCHECK(ch_seeds_network)
    ch_seeds = INPUTCHECK.out.seeds
    ch_seeds_multiqc = INPUTCHECK.out.multiqc
        .map{ meta, path -> path }
        .collectFile(
            cache: false,
            storeDir: "${params.outdir}/mqc_summaries",
            name: 'input_seeds_mqc.tsv',
            keepHeader: true
        )
    ch_multiqc_files = ch_multiqc_files.mix(ch_seeds_multiqc)

    // Save status for workflow summary
    ch_seeds_empty_status = ch_seeds_network
        .map{meta, seeds, network -> meta.id}
        .join(INPUTCHECK.out.seeds.map{ meta, seeds -> [meta.id, seeds]}, by: 0, remainder: true)
        .map{id, seeds -> [id, seeds == null] }

    // Add seeds modules to module channel
    // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), path(module)]
    ch_modules = INPUTCHECK.out.seeds_module
        .map{meta, path ->
            def dup = meta.clone()
            dup.amim = "no_tool"
            dup.id = meta.id + "." + dup.amim
            dup.module_id = dup.id
            [ dup, path ]
        }


    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        NETWORK EXPANSION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    // Network expansion tools
    NETWORKEXPANSION(ch_seeds, ch_network_gt)
    ch_modules = ch_modules.mix(NETWORKEXPANSION.out.modules) // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), path(module)]
    ch_versions = ch_versions.mix(NETWORKEXPANSION.out.versions)


    // Topology evaluation
    TOPOLOGY(ch_modules)
    ch_versions = ch_versions.mix(TOPOLOGY.out.versions)
    ch_topology_multiqc = TOPOLOGY.out.topology
        .map{ meta, path -> path }
        .collectFile(
            cache: false,
            storeDir: "${params.outdir}/mqc_summaries",
            name: 'topology_mqc.tsv',
            keepHeader: true
        )
    ch_multiqc_files = ch_multiqc_files.mix(ch_topology_multiqc)

    // Add topology information to module metadata
    // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), val(topology[nodes,edges]) ]
    ch_topology = TOPOLOGY.out.topology
        .map{meta, path -> [meta, readTsvAsListOfMaps(path)]}.transpose() // Parse topology information from tsv file
        .map{meta, topology -> [meta, topology + ["nodes": topology["nodes"].toInteger(), "edges": topology["edges"].toInteger()]]} // Parse to integer
        .map{meta, topology -> [meta, topology.subMap("nodes", "edges")]} // Select only nodes and edges

    // channel: [ val(meta[id,module_id,amim,seeds_id,network_id,nodes,edges]), path(module) ]
    ch_modules = ch_modules
        .join(ch_topology, by: 0, failOnDuplicate: true, failOnMismatch: true) // Join topology information to module metadata
        .map{meta, module, topology -> [meta + topology, module]}

    // Annotate with network properties
    // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), path(module), path(network) ]
    ch_module_network = ch_modules
        .map{ meta, module -> [meta.network_id, meta, module]}
        .combine(ch_network_gt.map{meta, network -> [meta.network_id, network]}, by: 0)
        .map{newtork_id, meta, module, network -> [meta, module, network]}

    NETWORKANNOTATION(ch_module_network)
    ch_modules = NETWORKANNOTATION.out.module
    ch_versions = ch_versions.mix(NETWORKANNOTATION.out.versions)


    // Save modules
    SAVEMODULES(ch_modules)
    ch_nodes_tsv_not_empty = SAVEMODULES.out.nodes_tsv
        .filter{meta, module -> meta.nodes > 0} // Filter out empty modules

    ch_versions = ch_versions.mix(SAVEMODULES.out.versions)

    // Separate empty modules
    ch_modules_empty_not_empty = ch_modules
        .branch{ meta, module ->
            empty: meta.nodes == 0
            not_empty: meta.nodes > 0
        }
    ch_modules_not_empty = ch_modules_empty_not_empty.not_empty

    // Save status for workflow summary
    ch_module_empty_status = ch_module_empty_status
        .mix(ch_modules_empty_not_empty.empty.map {meta, module -> [meta.id, true] })
        .mix(ch_modules_empty_not_empty.not_empty.map {meta, module -> [meta.id, false] })

    // Warning for empty modules in MultiQC report
    ch_modules_empty_not_empty
        .empty
        .map {meta, module -> "$meta.id\t$meta.nodes" }
        .collect()
        .map { tsv_data ->
            def header = ["Module\tNodes"]
            multiqcTsvFromList(tsv_data, header)
        }
        .collectFile(
            cache: false,
            storeDir: "${params.outdir}/mqc_summaries",
            name: "warn_empty_modules_mqc.tsv",
        ).set { ch_modules_empty_multiqc }
    ch_multiqc_files = ch_multiqc_files.mix(ch_modules_empty_multiqc)



    // Visualize modules
    if(!params.skip_visualization){
        ch_visualization_input = ch_modules_not_empty
            .branch {meta, module ->
                fail: meta.nodes > params.visualization_max_nodes
                pass: true
            }

        // Save status for workflow summary
        ch_visualization_skipped_status = ch_visualization_skipped_status
            .mix(ch_visualization_input.fail.map {meta, module -> [meta.id, true] })
            .mix(ch_visualization_input.pass.map {meta, module -> [meta.id, false] })

        // MultiQC report warning for too many nodes
        ch_visualization_input
            .fail
            .map {meta, module -> "$meta.id\t$meta.nodes" }
            .collect()
            .map { tsv_data ->
                def header = ["Module\tNodes"]
                multiqcTsvFromList(tsv_data, header)
            }
            .collectFile(
                cache: false,
                storeDir: "${params.outdir}/mqc_summaries",
                name: "warn_visualization_max_nodes_mqc.tsv",
            ).set { ch_visualization_multiqc }
        ch_multiqc_files = ch_multiqc_files.mix(ch_visualization_multiqc)

        VISUALIZEMODULES(ch_visualization_input.pass)
        ch_versions = ch_versions.mix(VISUALIZEMODULES.out.versions)
    }

    // Drugstone export
    if(!params.skip_drugstone_export){
        ch_drugstone_export_input = ch_modules_not_empty
            .branch {meta, module ->
                fail: meta.nodes > params.drugstone_max_nodes
                pass: true
            }

        // Save status for workflow summary
        ch_drugstone_skipped_status = ch_drugstone_skipped_status
        .mix(ch_drugstone_export_input.fail.map {meta, module -> [meta.id, true] })
        .mix(ch_drugstone_export_input.pass.map {meta, module -> [meta.id, false] })

        // MultiQC report warning for too many nodes
        ch_drugstone_export_input
            .fail
            .map {meta, module -> "$meta.id\t$meta.nodes" }
            .collect()
            .map { tsv_data ->
                def header = ["Module\tNodes"]
                multiqcTsvFromList(tsv_data, header)
            }
            .collectFile(
                cache: false,
                storeDir: "${params.outdir}/mqc_summaries",
                name: "warn_drugstone_max_nodes_mqc.tsv",
            ).set { ch_drugstone_multiqc }
        ch_multiqc_files = ch_multiqc_files.mix(ch_drugstone_multiqc)

        DRUGSTONEEXPORT(ch_drugstone_export_input.pass, id_space)
        ch_versions = ch_versions.mix(DRUGSTONEEXPORT.out.versions)
        ch_drugstone_export_multiqc = DRUGSTONEEXPORT.out.link
            .map{ meta, path -> path }
            .collectFile(
                cache: false,
                storeDir: "${params.outdir}/mqc_summaries",
                name: 'drugstone_link_mqc.tsv',
                keepHeader: true
            )
        ch_multiqc_files = ch_multiqc_files.mix(ch_drugstone_export_multiqc)
    }

    // Annotation and BIOPAX conversion
    if(!params.skip_annotation){
        if( params.id_space != "symbol" & params.id_space != "ensembl" ){
            GT_BIOPAX(ch_modules, id_space, validate_online)
            ch_versions = ch_versions.mix(GT_BIOPAX.out.versions)
        } else {
            log.warn("Skipping annotation and BioPAX conversion (currently only uniprot or entrez IDs)")
        }

    }


    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        MODULE EVALUATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    if(!params.skip_evaluation){

        GT2TSV_Modules(ch_modules_not_empty)
        GT2TSV_Network(ch_network_gt)

        // channel: [ val(meta), path(nodes) ]
        ch_nodes = GT2TSV_Modules.out

        // Module overlap
        ch_overlap_input = ch_nodes_tsv_not_empty
            .multiMap { meta, nodes ->
                ids: meta.id
                nodes: nodes
            }
        MODULEOVERLAP(
            ch_overlap_input.ids.collect(),
            ch_overlap_input.nodes.collect()
        )
        ch_multiqc_files = ch_multiqc_files.mix(MODULEOVERLAP.out)

        // Overrepresentation analysis
        if(!params.skip_gprofiler){

            ch_gprofiler_input = ch_nodes
                .map{ meta, path -> [meta.network_id, meta, path]}
                .combine(GT2TSV_Network.out.map{meta, path -> [meta.id, path]}, by: 0)
                .multiMap{key, meta, nodes, network ->
                    nodes: [meta, nodes]
                    network: [meta, network]
                }

            GPROFILER2_GOST (
                ch_gprofiler_input.nodes,
                [[],[]],
                ch_gprofiler_input.network
            )
            ch_versions = ch_versions.mix(GPROFILER2_GOST.out.versions)
        }

        // Digest
        if(!params.skip_digest){

            // Reference-free evaluation
            if(!params.skip_digest_reference_free){

                ch_digest_reference_free_input = ch_nodes_tsv_not_empty
                .map{ meta, nodes -> [meta.network_id, meta, nodes]}
                .combine(ch_network_gt.map{meta, network -> [meta.id, network]}, by: 0)
                .multiMap{key, meta, nodes, network ->
                    nodes: [meta, nodes]
                    network: network
                }

                DIGEST_REFERENCEFREE (ch_digest_reference_free_input.nodes, id_space, ch_digest_reference_free_input.network, id_space, "subnetwork")
                ch_versions = ch_versions.mix(DIGEST_REFERENCEFREE.out.versions)
                ch_multiqc_files = ch_multiqc_files.mix(
                    DIGEST_REFERENCEFREE.out.multiqc
                    .map{ meta, path -> path }
                    .collectFile(
                        cache: false,
                        storeDir: "${params.outdir}/mqc_summaries",
                        name: 'digest_reference_free_mqc.tsv',
                        keepHeader: true)
                )

            }

            // Reference-based evaluation
            if(!params.skip_digest_reference_based){
                ch_digest_reference_based_input = ch_nodes_tsv_not_empty
                    .filter{ meta, nodes -> meta.amim != "no_tool" } // Filter out no_tool modules
                    .map{ meta, nodes -> [meta.network_id, meta, nodes]}
                    .combine(ch_network_gt.map{meta, network -> [meta.id, network]}, by: 0)
                    .multiMap{key, meta, nodes, network ->
                        nodes: [meta, nodes]
                        network: network
                    }

                DIGEST_REFERENCEBASED (ch_digest_reference_based_input.nodes, id_space, ch_digest_reference_based_input.network, id_space, "subnetwork-set")
                ch_versions = ch_versions.mix(DIGEST_REFERENCEBASED.out.versions)
                ch_multiqc_files = ch_multiqc_files.mix(
                    DIGEST_REFERENCEBASED.out.multiqc
                    .map{ meta, path -> path }
                    .collectFile(
                        cache: false,
                        storeDir: "${params.outdir}/mqc_summaries",
                        name: 'digest_reference_based_mqc.tsv',
                        keepHeader: true)
                )

            }

        }

        // Seed perturbation based evaluation
        if(params.run_seed_perturbation){
            // Only use seed files with at least two nodes for the seed perturbation analysis
            // The information comes from the meta map of the "no_tool" disease modules, which are equivalent to the seed sets
            ch_filtered_seeds = ch_modules
                .filter{meta, _path -> meta.amim == "no_tool"}
                .map{meta, _module -> [meta.seeds_id, meta.network_id, meta.nodes]}
                .join(ch_seeds.map{meta, seeds -> [meta.seeds_id, meta.network_id, meta, seeds]}, by: [0,1], failOnDuplicate: true, failOnMismatch: true)
                .branch{_seeds_id, _network_id, nodes, _meta, _seeds ->
                    fail: nodes < 2
                    pass: true
                }
            ch_seed_perturbation_input  = ch_filtered_seeds.pass.map{_seeds_id, _network_id, _nodes, meta, seeds -> [meta, seeds]}
            GT_SEEDPERTURBATION(
                ch_modules.filter{ meta, path -> meta.amim != "no_tool" }, // Filter out no_tool modules
                ch_seed_perturbation_input,
                ch_network_gt
            )
            ch_versions = ch_versions.mix(GT_SEEDPERTURBATION.out.versions)
            ch_multiqc_files = ch_multiqc_files
                .mix(GT_SEEDPERTURBATION.out.multiqc_summary)
                .mix(GT_SEEDPERTURBATION.out.multiqc_jaccard)
        }

        // Network perturbation based evaluation
        if(params.run_network_perturbation){
            GT_NETWORKPERTURBATION(
                ch_modules.filter{ meta, path -> meta.amim != "no_tool" }, // Filter out no_tool modules
                ch_seeds,
                ch_network_gt,
                ch_perturbed_networks
            )
            ch_versions = ch_versions.mix(GT_NETWORKPERTURBATION.out.versions)
            ch_multiqc_files = ch_multiqc_files
                .mix(GT_NETWORKPERTURBATION.out.multiqc_summary)
                .mix(GT_NETWORKPERTURBATION.out.multiqc_jaccard)
        }

    }


    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        DRUG PRIORITIZATION
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    */

    if(!params.skip_drug_predictions){
        def valid_algorithms = ['trustrank', 'closeness', 'degree']

        // Split the algorithms and check if they are valid
        ch_algorithms_drugs = Channel
            .of(params.drugstone_algorithms.split(','))
            .filter { algorithm ->
                if (!valid_algorithms.contains(algorithm)) {
                    throw new IllegalArgumentException("Invalid algorithm: $algorithm. Must be one of: ${valid_algorithms.join(', ')}")
                }
                return true
            }

        ch_drugstone_input = ch_nodes_tsv_not_empty
            .branch {meta, module ->
                fail: meta.nodes > params.drugstone_max_nodes
                pass: true
            }

        ch_drugstone_input = ch_drugstone_input.pass
            .combine(ch_algorithms_drugs)
            .map { meta, module, algorithm ->
                [meta + [id: meta.id + "." + algorithm, drug_algorithm: algorithm], module, algorithm]
            }
            .multiMap { meta, module, algorithm ->
                module: [meta, module]
                algorithm: algorithm
            }
        includeIndirectDrugs = Channel.value(params.includeIndirectDrugs).map{it ? 1 : 0}
        includeNonApprovedDrugs = Channel.value(params.includeNonApprovedDrugs).map{it ? 1 : 0}
        DRUGPREDICTIONS(ch_drugstone_input.module, id_space, ch_drugstone_input.algorithm, includeIndirectDrugs, includeNonApprovedDrugs, params.result_size)
        ch_versions = ch_versions.mix(DRUGPREDICTIONS.out.versions)

        if(!params.skip_visualization){

            ch_drug_visualization_input = DRUGPREDICTIONS.out.drug_predictions
                .map{ meta, algorithm, drug_predictions -> [meta, drug_predictions] }
                .filter{ meta, drug_predictions -> meta.nodes <= params.visualization_max_nodes }       // Filter out modules with too many nodes
                .map{ meta, drug_predictions -> [meta.module_id, meta, drug_predictions] }              // Format for combining with modules
                .combine(ch_modules_not_empty.map{meta, module -> [meta.module_id, module]}, by: 0)     // Combine with modules
                .map{module_id, meta, drug_predictions, module -> [meta, module, drug_predictions] }    // Format for visualization

            VISUALIZEMODULESDRUGS(ch_drug_visualization_input)
            ch_versions = ch_versions.mix(VISUALIZEMODULESDRUGS.out.versions)
        }
    }

    // Drug prioritization - Proximity
    if(params.run_proximity){
        GT_PROXIMITY(
            ch_network_gt,
            ch_nodes_tsv_not_empty,
            ch_shortest_paths,
            proximity_dt)
        ch_versions = ch_versions.mix(GT_PROXIMITY.out.versions)
    }


    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'diseasemodulediscovery_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    seeds_empty_status              = ch_seeds_empty_status             // channel: [id, boolean]
    module_empty_status             = ch_module_empty_status            // channel: [id, boolean]
    visualization_skipped_status    = ch_visualization_skipped_status   // channel: [id, boolean]
    drugstone_skipped_status        = ch_drugstone_skipped_status       // channel: [id, boolean]
    multiqc_report                  = MULTIQC.out.report.toList()       // channel: /path/to/multiqc_report.html
    versions                        = ch_versions                       // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
