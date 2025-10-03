process HIERARCHICAL_HOTNET_PROCESS_HIERARCHIES {
    tag "$meta.id"
    label 'process_single'
    container "docker.io/motan04/hierarchical_hotnet:latest"

    input: 
    tuple val(meta), path(original_hierarchy_edges), path(original_hierarchy_nodes), path(permuted_hierarchy_edges), path(permuted_hierarchy_nodes)
    output:
    tuple val(meta), path("${meta.id}.module"), emit:modules
    path "versions.yml"                       , emit: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    """
    python /hierarchical-hotnet/src/process_hierarchies.py \
        --observed_edge_list_file ${original_hierarchy_edges} \
        --observed_index_gene_file ${original_hierarchy_nodes} \
        --permuted_edge_list_files ${permuted_hierarchy_edges} \
        --permuted_index_gene_files ${permuted_hierarchy_nodes} \
        -lsb 1 \
        --cluster_file ${meta.id}.module
     cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """

}