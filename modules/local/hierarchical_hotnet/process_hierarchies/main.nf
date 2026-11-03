process HIERARCHICAL_HOTNET_PROCESS_HIERARCHIES {
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/d9/d9ad2dd27f50f0e332b61bf6e8e5562d9ef62575bea80abf26a8a0270d87b00a/data'
        : 'community.wave.seqera.io/library/hierarchical_hotnet:9d9481ba9020b769'}"

    input:
    tuple val(meta), path(original_hierarchy_edges), path(original_hierarchy_nodes), path(permuted_hierarchy_edges), path(permuted_hierarchy_nodes)
    val(lower_size_bound)
    output:
    tuple val(meta), path("${meta.id}.module"), emit:modules
    path "versions.yml"                       , emit: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    python -m process_hierarchies \
        $args \
        --observed_edge_list_file ${original_hierarchy_edges} \
        --observed_index_gene_file ${original_hierarchy_nodes} \
        --permuted_edge_list_files ${permuted_hierarchy_edges} \
        --permuted_index_gene_files ${permuted_hierarchy_nodes} \
        --lower_size_bound $lower_size_bound \
        --cluster_file ${meta.id}.module
     cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        networkX: \$(python -c "import networkx; print(networkx.__version__)")
        numpy: \$(python -c "import numpy; print(numpy.__version__)")
        scipy: \$(python -c "import scipy; print(scipy.__version__)")
    END_VERSIONS
    """

}
