//
// Runs network perturbation based evaluation of network expansion methods
//

include { NETWORKEXPANSION             } from '../networkexpansion'
include { NETWORKPERTURBATION           } from '../../../modules/local/networkperturbation/main'
include { NETWORKPERTURBATIONEVALUATION } from '../../../modules/local/networkperturbationevaluation/main'

workflow GT_NETWORKPERTURBATION {
    take:
    ch_modules              // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), path(module) ]
    ch_seeds                // channel: [ val(meta[id,seeds_id,network_id]), path(seeds) ]
    ch_network              // channel: [ val(meta[id,network_id]), path(network) ]
    ch_perturbed_networks    // channel: [ val(meta[id,network_id]), [path(perturbed_networks)] ]

    main:
    ch_versions = Channel.empty()

    // Branch ch_perturbed_networks based on whether the perturbed_networks have already been pre-computed
    ch_perturbed_networks = ch_network
        .join(ch_perturbed_networks, by: 0, failOnDuplicate: true, failOnMismatch: true)
        .branch{
            precomputed: it[2].size() > 0
            not_precomputed: true
        }

    // Perturbe the input network(s)
    // channel: [val(meta[id,network_id,n_perturbations]), path(perturbed_networks), val(output_name)]
    ch_perturbation_input = ch_perturbed_networks.not_precomputed
        // add n_perturbations to meta
        .map{meta, network, perturbed_networks -> [meta + [n_perturbations: params.n_network_perturbations], network]}
        // expand by number of perturbations
        .combine(Channel.of(0..(params.n_network_perturbations-1)))
        // add output file names
        .map{meta, network, perturbation -> [meta, network, network.baseName + ".perm_" + perturbation + "." + network.extension]}

    // Run network perturbations
    NETWORKPERTURBATION(ch_perturbation_input)
    ch_versions = ch_versions.mix(NETWORKPERTURBATION.out.versions)

    // Create required shape for NETWORKEXPANSION
    // channel: [val(meta[id,seeds_id,network_id,perturbed_network_id,n_perturbations]), path(perturbed_network)]
    ch_perturbed_networks =
        // Bring precomputed perturbed networks in right shape
        ch_perturbed_networks.precomputed.map{ meta, network, perturbed_networks -> [meta, perturbed_networks] }
        // Add n_perturbations for later grouping
        .map{ meta, perturbed_networks -> [ meta + [n_perturbations: perturbed_networks.size()], perturbed_networks] }
        // Convert to long format
        .transpose()
        // Mix with precomputed perturbations
        .mix(NETWORKPERTURBATION.out.perturbed_network)
        // Update id and perturbed_network_id based on perturbed network (original id is still stored as network_id) for the module parser
        .map{meta, perturbed_network ->
            def dup = meta.clone()
            dup.id = perturbed_network.baseName
            dup.perturbed_network_id = dup.id
            [ dup, perturbed_network]
        }

    // Run network expansion tools on perturbed networks
    NETWORKEXPANSION(ch_seeds, ch_perturbed_networks)
    ch_versions = ch_versions.mix(NETWORKEXPANSION.out.versions)

    // Group by seeds_id, amim, and network_id to get one element per original module
    // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), [path(perturbed_modules)] ]
    ch_perturbed_modules = NETWORKEXPANSION.out.modules
        .map{meta, perturbed_module->
            key = groupKey(meta.subMap("seeds_id", "amim", "network_id"), meta.n_perturbations)
            [key, meta, perturbed_module]
        }
        // Group by seeds_id, amim, and network_id
        .groupTuple()
        // Add id and module_id based on the original modules
        .map{key, meta, perturbed_modules ->
            [ [ id: key.seeds_id + "." + key.network_id + "." + key.amim, module_id: key.seeds_id + "." + key.network_id + "." + key.amim, amim: key.amim, seeds_id: key.seeds_id, network_id: key.network_id], perturbed_modules]
        }

    // Join perturbed modules with original modules
    ch_evaluation = ch_modules.map{meta, module -> [meta.module_id, meta, module]}
        // Join with perturbed modules
        .join(
            ch_perturbed_modules.map{meta, perturbed_modules -> [meta.module_id, perturbed_modules]},
            by: 0, failOnDuplicate: true, failOnMismatch: true
        )
        // Prepare channel for evaluation
        .multiMap{module_id, meta, module, perturbed_modules ->
            module: [meta, module]
            perturbed_modules: perturbed_modules
        }

    NETWORKPERTURBATIONEVALUATION(
        ch_evaluation.module,
        ch_evaluation.perturbed_modules,
    )
    ch_versions = ch_versions.mix(NETWORKPERTURBATIONEVALUATION.out.versions)
    ch_multiqc_summary =  NETWORKPERTURBATIONEVALUATION.out.multiqc_summary
        .map{ meta, path -> path }
        .collectFile(
            cache: false,
            storeDir: "${params.outdir}/mqc_summaries",
            name: 'network_perturbation_mqc.tsv',
            keepHeader: true
        )
    ch_multiqc_jaccard =
        NETWORKPERTURBATIONEVALUATION.out.multiqc_jaccard
        .map{ meta, path -> path }
        .collectFile(
            item -> "  " + item.text,
            cache: false,
            storeDir: "${params.outdir}/mqc_summaries",
            name: 'network_perturbation_jaccard_mqc.yaml',
            sort: true,
            seed: new File("$projectDir/assets/network_perturbation_jaccard_header.yaml").text
        )



    emit:
    versions = ch_versions                  // channel: [ versions.yml ]        emit collected versions
    multiqc_summary = ch_multiqc_summary    // channel: [ multiqc_summary ]     emit collected multiqc files
    multiqc_jaccard = ch_multiqc_jaccard    // channel: [ multiqc_jaccard ]     emit collected multiqc files
}
