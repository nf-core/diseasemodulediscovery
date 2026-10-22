process HIERARCHICAL_HOTNET_CONSTRUCT_HIERARCHIES {
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0f/0ff202606a65efc9b3c4898270051a4caaf044a3c2550831a4e1f79dce421bca/data'
        : 'community.wave.seqera.io/library/hierarchical_hotnet:8bea4d8e8f9b32f2'}"

    input:
    tuple val(meta), path(nodes), path(edges), path(similarity_matrix), path(node_score), val(permutation)
    output:
    tuple val(meta), path("${meta.id}.hierarchy_edge_list*"), path("${meta.id}.hierarchy_node_list*"), emit: hierarchy
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    python ${projectDir}/bin/hierarchical_hotnet/construct_hierarchy.py \
        $args \
        -smf ${similarity_matrix} \
        -igf ${nodes} \
        -gsf ${node_score} \
        -helf ${meta.id}.hierarchy_edge_list_${permutation}.tsv \
        -higf ${meta.id}.hierarchy_node_list_${permutation}.tsv
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        networkX: \$(python -c "import networkx; print(networkx.__version__)")
        numpy: \$(python -c "import numpy; print(numpy.__version__)")
        scipy: \$(python -c "import scipy; print(scipy.__version__)")
    END_VERSIONS
    """
}
