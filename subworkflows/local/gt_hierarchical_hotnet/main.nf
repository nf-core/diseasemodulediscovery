include { PREFIXLINES       } from '../../../modules/local/prefixlines/main'
include { GRAPHTOOLPARSER   } from '../../../modules/local/graphtoolparser/main'
include { HIERARCHICAL_HOTNET_SCORE_PARSER} from '../../../modules/local/hierarchical_hotnet/score_parser/main'
include { HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX } from '../../../modules/local/hierarchical_hotnet/construct_similarity_matrix/main'
include { HIERARCHICAL_HOTNET_PERMUTE_SCORES} from '../../../modules/local/hierarchical_hotnet/permute_scores/main'
include { HIERARCHICAL_HOTNET_CONSTRUCT_HIERARCHIES } from '../../../modules/local/hierarchical_hotnet/construct_hierarchies/main'

workflow GT_HIERARCHICAL_HOTNET {
    take:
    ch_seeds
    ch_network

    main:
    ch_versions = Channel.empty()
    GRAPHTOOLPARSER(ch_network, "hierarchical_hotnet")
    ch_versions = ch_versions.mix(GRAPHTOOLPARSER.out.versions)
    ch_hierarchical_hotnet_input = ch_seeds
        .map{ meta, seeds -> [meta.network_id, meta, seeds] }
        .combine(GRAPHTOOLPARSER.out.network.map{ meta, network -> [meta.network_id, meta, network] }, by: 0)
        .map{ network_id, seeds_meta, seeds, network_meta, network ->
            def meta = seeds_meta + network_meta
            meta.id = seeds_meta.seeds_id + "." + network_meta.id
            meta.amim = "hierarchical_hotnet"
            [meta, seeds, network]
        }
    HIERARCHICAL_HOTNET_SCORE_PARSER(ch_hierarchical_hotnet_input)
    HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX(GRAPHTOOLPARSER.out.network)
    ch_versions = ch_versions.mix(HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX.out.versions)
    ch_permutation_input = GRAPHTOOLPARSER.out.network
        .join(HIERARCHICAL_HOTNET_SCORE_PARSER.out,failOnMismatch: true, failOnDuplicate: true)
    ch_permutation_input.view()
    HIERARCHICAL_HOTNET_PERMUTE_SCORES(ch_permutation_input)

    emit:
    module = HIERARCHICAL_HOTNET_SCORE_PARSER.out
    versions = ch_versions
}
