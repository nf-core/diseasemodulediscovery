process HIERARCHICAL_HOTNET_CONSTRUCT_SIMILARITY_MATRIX {
    tag "$meta.id"
    label 'process_single'
    container "docker.io/motan04/hierarchical-hotnet:latest"

    input:
    tuple val(meta), path(edge_list)
    output:
    tuple val(meta), path("${meta.id}.similarity_matrix.h5"), emit: similarity_matrix
    path "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when
    script:
    """
    python hierarchical-hotnet/src/create_similarity_matrix.py \
        -i ${edge_list} \
        -o "${meta.id}.similarity_matrix.h5" \
        -bof "${meta.id}.beta.txt"
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
