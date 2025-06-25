process HIERARCHICAL_HOTNET_CONSTRUCT_HIERARCHIES {
    tag "$meta.id"
    label 'process_single'
    container "docker.io/motan04/hierarchical-hotnet:latest"

    input:
    tuple val(meta), path(nodes), path(edges), path(original_score), path(permuted_scores), path(similarity_matrix)

    output:
    tuple val(meta), path("${meta.id}.hierarchies"), emit: hierarchies
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    for i in 'seq 0 4'
    do
        python hierarchical-hotnet/src/construct_hierarchiy.py \\
            -smf ${similarity_matrix} \\
            -igf ${nodes} \\
            -gsf ${permuted_scores}.permuted_scores.\$i.tsv \\
            -helf ${meta.id}.hierarchies/hierarchy_edge_list_\$i.tsv \\
            -higf ${meta.id}.hierarchies/hierarchy_node_list_\$i.tsv \\
    done
    python hierarchical-hotnet/src/construct_hierarchiy.py \\
        -smf ${similarity_matrix} \\
        -igf ${nodes} \\
        -gsf ${original_score} \\
        -helf ${meta.id}.hierarchies/hierarchy_edge_list_original.tsv \\
        -higf ${meta.id}.hierarchies/hierarchy_node_list_original.tsv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
