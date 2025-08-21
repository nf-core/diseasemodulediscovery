process HIERARCHICAL_HOTNET_CONSTRUCT_HIERARCHIES {
    tag "$meta.id"
    label 'process_single'
    container "docker.io/motan04/hierarchical_hotnet:latest"

    input:
    tuple val(meta), path(nodes), path(edges), path(similarity_matrix), path(node_score)
    output:
    tuple val(meta), path("${meta.id}.hierarchy_edge_list.tsv"), path("${meta.id}.hierarchy_node_list.tsv"), emit: hierarchy
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    python /tmp/hierarchical-hotnet/src/construct_hierarchy.py \
        -smf ${similarity_matrix} \
        -igf ${nodes} \
        -gsf ${node_score} \
        -helf ${meta.id}.hierarchy_edge_list.tsv \
        -higf ${meta.id}.hierarchy_node_list.tsv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
