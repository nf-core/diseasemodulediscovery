//
// Runs all the expansion methods
//

include { GT_DIAMOND            } from '../gt_diamond'
include { GT_DOMINO             } from '../gt_domino'
include { GT_ROBUST             } from '../gt_robust'
include { GT_ROBUSTBIASAWARE    } from '../gt_robust_bias_aware'
include { GT_FIRSTNEIGHBOR      } from '../gt_firstneighbor'
include { GT_RWR                } from '../gt_rwr'
include { MODULEPARSER          } from '../../../modules/local/moduleparser/main'

workflow NETWORKEXPANSION {
    take:
    ch_seeds    // channel: [ val(meta[id,seeds_id,network_id]), path(seeds) ]
    ch_network  // channel: [ val(meta[id,network_id]), path(network) ]

    main:
    // Params
    diamond_n = channel.value(params.diamond_n)
    diamond_alpha = channel.value(params.diamond_alpha)

    rwr_scaling = channel.value(params.rwr_scaling).map{flag -> flag ? 1 : 0}
    rwr_symmetrical = channel.value(params.rwr_symmetrical).map{flag -> flag ? 1 : 0}
    rwr_r = channel.value(params.rwr_r)

    id_space = channel.value(params.id_space)

    ch_modules  = channel.empty()
    ch_raw_modules = channel.empty()

    if(!params.skip_diamond){
        GT_DIAMOND(ch_seeds, ch_network, diamond_n, diamond_alpha)
        ch_raw_modules = ch_raw_modules.mix(GT_DIAMOND.out.module)
    }

    if(!params.skip_domino){
        GT_DOMINO(ch_seeds, ch_network)
        ch_raw_modules = ch_raw_modules.mix(GT_DOMINO.out.module)
    }

    if(!params.skip_robust){
        GT_ROBUST(ch_seeds, ch_network)
        ch_raw_modules = ch_raw_modules.mix(GT_ROBUST.out.module)
    }

    if(!params.skip_robust_bias_aware){
        GT_ROBUSTBIASAWARE(ch_seeds, ch_network, id_space)
        ch_raw_modules = ch_raw_modules.mix(GT_ROBUSTBIASAWARE.out.module)
    }

    if(!params.skip_firstneighbor){
        GT_FIRSTNEIGHBOR(ch_seeds, ch_network)
        ch_modules = ch_modules.mix(GT_FIRSTNEIGHBOR.out.module)
    }

    if(!params.skip_rwr){
        GT_RWR(ch_seeds, ch_network, rwr_scaling, rwr_symmetrical, rwr_r)
        ch_raw_modules = ch_raw_modules.mix(GT_RWR.out.module)
    }

    // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), path(module), path(seeds), path(network) ]
    ch_module_parser_input = ch_raw_modules
        .map{meta, module -> [meta.seeds_id, meta.network_id, meta, module]}
        // combine with seeds
        .combine(ch_seeds.map{meta, seeds -> [meta.seeds_id, meta.network_id, seeds]}, by: [0,1])
        .map{_seeds_id, _network_id, meta, module, seeds ->
            [meta.perturbed_network_id==null ?  meta.network_id: meta.perturbed_network_id , meta, module, seeds] // Use perturbed_network_id, if available
        }
        // combine with network (perturbed network, if available)
        .combine(
            ch_network.map{ meta, network ->
                [meta.perturbed_network_id==null ?  meta.network_id: meta.perturbed_network_id, network] // Use perturbed_network_id, if available
            }, by: 0
        )
        // add amim to id and module_id
        .map{_network_id, meta, module, seeds, network ->
            def dup = meta.clone()
            dup.id = meta.id + "." + dup.amim
            dup.module_id = dup.id
            [ dup, module, seeds, network ]
        }

    MODULEPARSER(ch_module_parser_input)
    ch_modules = ch_modules.mix(MODULEPARSER.out.module)

    emit:
    modules  = ch_modules               // channel: [ val(meta[id,module_id,amim,seeds_id,network_id]), path(module) ]
}
