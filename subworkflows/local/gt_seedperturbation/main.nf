//
// Runs seed perturbation based evaluation of network expansion methods
//

include { NETWORKEXPANSION              } from '../networkexpansion'
include { SEEDPERTURBATION               } from '../../../modules/local/seedperturbation/main'
include { SEEDPERTURBATIONEVALUATION     } from '../../../modules/local/seedperturbationevaluation/main'
include { SEEDPERTURBATIONVISUALIZATION  } from '../../../modules/local/seedperturbationvisualization/main'

workflow GT_SEEDPERTURBATION {
    take:
    ch_modules  // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), path(module) ]
    ch_seeds    // channel: [ val(meta[id,seeds_id,network_id]), path(seeds) ]
    ch_network  // channel: [ val(meta[id,network_id]), path(network) ]


    main:

    ch_versions = Channel.empty()

    // Perturbe the input seeds
    SEEDPERTURBATION(ch_seeds)
    ch_versions = ch_versions.mix(SEEDPERTURBATION.out.versions)

    // Create required shape for NETWORKEXPANSION
    // channel: [val(meta[id,seeds_id,network_id,original_seeds_id,n_perturbations]), path(perturbed_seeds)]
    ch_perturbed_seeds = SEEDPERTURBATION.out.perturbed_seeds
        // Add original meta.id as original_seeds_id and n_perturbations
        .map{meta, perturbed_seeds ->
            def dup = meta.clone()
            dup.original_seeds_id = meta.seeds_id
            dup.n_perturbations = perturbed_seeds.size()
            [ dup, perturbed_seeds]
        }
        // Convert to long format
        .transpose()
        // Update id and seeds_id based on perturbed seeds (original id is still stored as original_seeds_id)
        .map{meta, perturbed_seeds ->
            def dup = meta.clone()
            dup.id = perturbed_seeds.baseName + "." + meta.network_id
            dup.seeds_id = perturbed_seeds.baseName
            [ dup, perturbed_seeds]
        }


    // Run network expansion tools on perturbed seeds
    NETWORKEXPANSION(ch_perturbed_seeds, ch_network)
    ch_versions = ch_versions.mix(NETWORKEXPANSION.out.versions)

    // Group by original_seeds_id, amim, and network_id to get one element per original module
    // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), [path(perturbed_modules)], [path(perturbed_seeds)] ]
    ch_perturbed_modules = NETWORKEXPANSION.out.modules
        //  Combine with perturbed seeds
        .map{meta, perturbed_module -> [meta.seeds_id, meta.network_id, meta, perturbed_module]}
        .combine(ch_perturbed_seeds.map{meta, perturbed_seeds -> [meta.seeds_id, meta.network_id, perturbed_seeds]}, by: [0,1])
        // Add original_seeds_id, amim, and network_id to tuple for grouping
        .map{seeds_id, network_id, meta, perturbed_module, perturbed_seeds ->
            key = groupKey(meta.subMap("original_seeds_id", "amim", "network_id"), meta.n_perturbations)
            [key, meta, perturbed_module, perturbed_seeds]
        }
        // Group by original_seeds_id, amim, and network_id
        .groupTuple()
        // Add an ID (based on the original seeds)
        .map{key, meta, perturbed_modules, perturbed_seeds ->
            [ [ id: key.original_seeds_id + "." + key.network_id + "." + key.amim, module_id: key.original_seeds_id + "." + key.network_id + "." + key.amim, amim: key.amim, seeds_id: key.original_seeds_id, network_id: key.network_id], perturbed_modules, perturbed_seeds]
        }


    // Combine with original modules, seeds, and network
    // Shape: [val(meta[id,module_id,amim,seeds_id,network_id]), path(original_module), path(original_seeds), [path(perturbed_modules)], [path(perturbed_seeds)], network]
    ch_evaluation = ch_modules
        // Combine modules with seeds
        .map{meta, module -> [meta.seeds_id, meta.network_id, meta, module]}
        .combine(ch_seeds.map{meta, seeds -> [meta.seeds_id, meta.network_id, seeds]}, by: [0,1])
        .map{seeds_id, network_id, meta, module, seeds -> [meta.module_id, meta, module, seeds]}
        // Joine modules with perturbed modules and seeds
        .join(ch_perturbed_modules
            .map{ meta, perturbed_modules, perturbed_seeds ->
                [meta.module_id, perturbed_modules, perturbed_seeds]
            }, by: 0, failOnDuplicate: true, failOnMismatch: true
        )
        // Combine with network (key is network_id)
        .map{module_id, meta, module, seeds, perturbed_modules, perturbed_seeds ->
            [meta.network_id, meta, module, seeds, perturbed_modules, perturbed_seeds]
        }
        .combine(ch_network.map{meta, network-> [meta.network_id, network]}, by: 0)
        // Multimap to create the final shape
        .multiMap{network_id, meta, module, seeds, perturbed_modules, perturbed_seeds, network ->
            module: [meta, module]
            seeds: seeds
            perturbed_seeds: perturbed_seeds
            perturbed_modules: perturbed_modules
            network: network
        }


    // Evaluation
    SEEDPERTURBATIONEVALUATION(
        ch_evaluation.module,
        ch_evaluation.seeds,
        ch_evaluation.perturbed_modules,
        ch_evaluation.perturbed_seeds,
        ch_evaluation.network
    )
    ch_versions = ch_versions.mix(SEEDPERTURBATIONEVALUATION.out.versions)
    ch_multiqc_summary =  SEEDPERTURBATIONEVALUATION.out.multiqc_summary
        .map{ meta, path -> path }
        .collectFile(
            cache: false,
            storeDir: "${params.outdir}/mqc_summaries",
            name: 'seed_perturbation_mqc.tsv',
            keepHeader: true
        )
    ch_multiqc_jaccard =
        SEEDPERTURBATIONEVALUATION.out.multiqc_jaccard
        .map{ meta, path -> path }
        .collectFile(
            item -> "  " + item.text,
            cache: false,
            storeDir: "${params.outdir}/mqc_summaries",
            name: 'seed_perturbation_jaccard_mqc.yaml',
            sort: true,
            seed: new File("$projectDir/assets/seed_perturbation_jaccard_header.yaml").text
        )

    // Gene-level visualization
    ch_visualization_input = SEEDPERTURBATIONEVALUATION.out.detailed
        .multiMap { meta, path ->
            seeds_id: meta.seeds_id
            network_id: meta.network_id
            amim: meta.amim
            path: path
        }
    SEEDPERTURBATIONVISUALIZATION(
        ch_visualization_input.seeds_id.collect(),
        ch_visualization_input.network_id.collect(),
        ch_visualization_input.amim.collect(),
        ch_visualization_input.path.collect()
    )



    emit:
    versions = ch_versions                  // channel: [ versions.yml ]        emit collected versions
    multiqc_summary = ch_multiqc_summary    // channel: [ multiqc_summary ]     emit collected multiqc files
    multiqc_jaccard = ch_multiqc_jaccard    // channel: [ multiqc_jaccard ]     emit collected multiqc files
}
