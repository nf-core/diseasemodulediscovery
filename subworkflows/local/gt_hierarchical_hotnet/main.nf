include { PREFIXLINES       } from '../../../modules/local/prefixlines/main'
include { HIERARCHICAL_HOTNET_INPUT_PARSER } from '../../../modules/local/hierarchical_hotnet/input_parser/main'
include { HIERARCHICAL_HOTNET_SCORE_PARSER } from '../../../modules/local/hierarchical_hotnet/score_parser/main'
include { HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX } from '../../../modules/local/hierarchical_hotnet/construct_similarity_matrix/main'
include { HIERARCHICAL_HOTNET_PERMUTE_SCORES} from '../../../modules/local/hierarchical_hotnet/permute_scores/main'
include { HIERARCHICAL_HOTNET_CONSTRUCT_HIERARCHIES } from '../../../modules/local/hierarchical_hotnet/construct_hierarchies/main'

workflow GT_HIERARCHICAL_HOTNET {
    take:
    ch_seeds
    ch_network

    main:
    ch_versions = Channel.empty()
    HIERARCHICAL_HOTNET_INPUT_PARSER(ch_network) //emits: [val(meta), node_list], [val(meta), edge_list] 
    ch_versions = ch_versions.mix(HIERARCHICAL_HOTNET_INPUT_PARSER.out.versions)
    ch_score_parser = ch_seeds
        .map{ meta, seeds -> [meta.network_id, meta, seeds] }
        .combine(HIERARCHICAL_HOTNET_INPUT_PARSER.out.node_list.map{ meta, node_list -> [meta.network_id, meta, node_list] }, by: 0)
        .map{ _network_id, seeds_meta, seeds, node_list_meta, node_list ->
            def meta = seeds_meta + node_list_meta
            meta.id = seeds_meta.seeds_id + "." + node_list_meta.id
            meta.amim = "hierarchical_hotnet"
            [meta, seeds, node_list]
        } //[id, seeds_id, network_id, original_seeds_id, n_permutations, amim, seeds, node_list]
    HIERARCHICAL_HOTNET_SCORE_PARSER(ch_score_parser)
    HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX(HIERARCHICAL_HOTNET_INPUT_PARSER.out.edge_list)
    ch_permutation_input = ch_score_parser
        .map{ meta, _seeds, node_list -> [meta, node_list]}
        .join(HIERARCHICAL_HOTNET_INPUT_PARSER.out.edge_list, by: 0)
    ch_permutation_input.view()
    emit:
    module = HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX.out.similarity_matrix
    versions = ch_versions
}
