//
// Prepares the input for DIAMOnD and runs the tool
//

include { GRAPHTOOLPARSER   } from '../../../modules/local/graphtoolparser/main'
include { DIAMOND           } from '../../../modules/local/diamond/main'

workflow GT_DIAMOND {
    take:                                   // Workflow inputs
    ch_seeds                                // channel: [ val(meta[id,seeds_id,network_id]), path(seeds) ]
    ch_network                              // channel: [ val(meta[id,network_id]), path(network) ]
    n                                       // DIAMOnD specific parameter "n"
    alpha                                   // DIAMOnD spefific parameter "alpha"


    main:

    GRAPHTOOLPARSER(ch_network, "diamond")                                  // Convert gt file to diamond specific format

    // channel: [ val(meta[id,seeds_id,network_id), path(seeds), path(network) ]
    ch_diamond_input = ch_seeds
        .map{ meta, seeds -> [meta.network_id, meta, seeds]}
        .combine(GRAPHTOOLPARSER.out.network.map{ meta, network -> [meta.network_id, meta, network]}, by: 0)
        .map{_network_id, seeds_meta, seeds, network_meta, network ->
            def meta = seeds_meta + network_meta
            meta.id = seeds_meta.seeds_id + "." + network_meta.id
            meta.amim = "diamond"
            [meta, seeds, network]
        }

    DIAMOND(ch_diamond_input, n, alpha)                                     // Run diamond on parsed network

    emit:
    module   = DIAMOND.out.module       // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), path(module) ]
}
