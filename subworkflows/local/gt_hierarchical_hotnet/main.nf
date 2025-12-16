include { PREFIXLINES       } from '../../../modules/local/prefixlines/main'
include { HIERARCHICAL_HOTNET_INPUT_PARSER } from '../../../modules/local/hierarchical_hotnet/input_parser/main'
include { HIERARCHICAL_HOTNET_SCORE_PARSER } from '../../../modules/local/hierarchical_hotnet/score_parser/main'
include { HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX } from '../../../modules/local/hierarchical_hotnet/construct_similarity_matrix/main'
include { HIERARCHICAL_HOTNET_PERMUTE_SCORES} from '../../../modules/local/hierarchical_hotnet/permute_scores/main'
include { HIERARCHICAL_HOTNET_CONSTRUCT_HIERARCHIES } from '../../../modules/local/hierarchical_hotnet/construct_hierarchies/main'
include { HIERARCHICAL_HOTNET_CONSTRUCT_HIERARCHIES as CONSTRUCT_PERMUTED_HIERARCHIES} from '../../../modules/local/hierarchical_hotnet/construct_hierarchies/main'
include { HIERARCHICAL_HOTNET_PROCESS_HIERARCHIES } from '../../../modules/local/hierarchical_hotnet/process_hierarchies/main'
workflow GT_HIERARCHICAL_HOTNET {
    take:
    ch_seeds
    ch_network
    num_permutations
    lower_size_bound
    main:
    ch_versions = Channel.empty()
    HIERARCHICAL_HOTNET_INPUT_PARSER(ch_network) //emits: [val(meta), node_list, edge_list]
    ch_versions = ch_versions.mix(HIERARCHICAL_HOTNET_INPUT_PARSER.out.versions)
    ch_parsed_inputs = ch_seeds
        .map{ meta, seeds -> [meta.network_id, meta, seeds] }
        .combine(HIERARCHICAL_HOTNET_INPUT_PARSER.out.network.map{ meta, node_list, edge_list -> [meta.network_id, meta, node_list, edge_list] }, by: 0)
        .map{ _network_id, seeds_meta, seeds, network_meta, node_list, edge_list ->
            def meta = seeds_meta + network_meta
            meta.id = seeds_meta.seeds_id + "." + network_meta.id
            meta.amim = "hierarchical_hotnet"
            [meta, seeds, node_list, edge_list]
        }
    HIERARCHICAL_HOTNET_SCORE_PARSER(ch_parsed_inputs.map{meta, seeds, node_list, _edge_list -> [meta, seeds, node_list] })
    HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX(ch_parsed_inputs.map{meta, _seeds, _node_list, edge_list -> [meta, edge_list] })
    ch_versions = ch_versions.mix(HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX.out.versions)
    ch_permutation_input = ch_parsed_inputs
        .map{ meta, _seeds, node_list, edge_list -> [meta, node_list, edge_list]}
        .join(HIERARCHICAL_HOTNET_SCORE_PARSER.out)
    HIERARCHICAL_HOTNET_PERMUTE_SCORES(ch_permutation_input, num_permutations)
    ch_versions = ch_versions.mix(HIERARCHICAL_HOTNET_PERMUTE_SCORES.out.versions)

    ch_parsed_inputs = ch_parsed_inputs
        .map{ meta, _seeds, node_list, edge_list -> [meta, node_list, edge_list]}
        .join(HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX.out.similarity_matrix)

    ch_permuted_hierarchy_input = ch_parsed_inputs
        .combine(HIERARCHICAL_HOTNET_PERMUTE_SCORES.out.permuted_scores
            .transpose()
            .map{
                meta, permuted_scores ->
                    def tokens = permuted_scores.toString().tokenize('.')
                    def permutation = tokens[-2]
                    [meta, permuted_scores, permutation]
                }
        , by: 0)
    CONSTRUCT_PERMUTED_HIERARCHIES(ch_permuted_hierarchy_input)
    ch_versions = ch_versions.mix(CONSTRUCT_PERMUTED_HIERARCHIES.out.versions)
    ch_hierarchy_input = ch_parsed_inputs
        .join(HIERARCHICAL_HOTNET_SCORE_PARSER.out, by: 0)
        .map{
            meta, node_list, edge_list, similarity_matrix, node_score ->
                [meta, node_list, edge_list, similarity_matrix, node_score, "original"]
        }
    HIERARCHICAL_HOTNET_CONSTRUCT_HIERARCHIES(ch_hierarchy_input)
    ch_versions = ch_versions.mix(HIERARCHICAL_HOTNET_CONSTRUCT_HIERARCHIES.out.versions)
   CONSTRUCT_PERMUTED_HIERARCHIES.out.hierarchy.groupTuple()
    ch_hierarchies = HIERARCHICAL_HOTNET_CONSTRUCT_HIERARCHIES.out.hierarchy
        .join(CONSTRUCT_PERMUTED_HIERARCHIES.out.hierarchy.groupTuple())
    HIERARCHICAL_HOTNET_PROCESS_HIERARCHIES(ch_hierarchies, lower_size_bound)
    ch_versions = ch_versions.mix(HIERARCHICAL_HOTNET_PROCESS_HIERARCHIES.out.versions)
    emit:
    module = HIERARCHICAL_HOTNET_PROCESS_HIERARCHIES.out.modules
    versions = ch_versions
}
