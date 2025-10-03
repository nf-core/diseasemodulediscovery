process HIERARCHICAL_HOTNET_PERMUTE_SCORES {
    tag "$meta.id"
    label 'process_single'
    container "docker.io/motan04/hierarchical_hotnet:latest"

    input:
    tuple val(meta), path(node_list), path(edge_list), path(node_scores)
    output:
    tuple val(meta), path("${meta.id}.score_permutation*"), emit: permuted_scores
    path "versions.yml"                                , emit: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    """
    python /hierarchical-hotnet/src/find_permutation_bins.py \
        -gsf ${node_scores} \
        -igf ${node_list} \
        -elf ${edge_list} \
        -o ${meta.id}.score_bins.tsv

    for i in `seq 100`
    do
        python /hierarchical-hotnet/src/permute_scores.py \
            -i ${node_scores} \
            -bf ${meta.id}.score_bins.tsv \
            -s \$i \
            -o ${meta.id}.score_permutation_\$i.tsv
    done
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

}
