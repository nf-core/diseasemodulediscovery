process HIERARCHICAL_HOTNET_INPUT_PARSER {
    tag "meta.id"
    label 'process_single'
    
    input:
    tuple val(meta), (path(network))
    
    output:
    tuple val(meta), path("*.node_list.tsv"), path("*.edge_list.tsv") , emit: network
    path "versions.yml"                                         , emit: versions 

    when:
    task.ext.when == null || task.ext.when
    
    script:
    """
    graph_tool_parser.py $network -f hierarchical_hotnet -l DEBUG

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        graph-tool: \$(python -c "import graph_tool; print(graph_tool.__version__)")
    END_VERSIONS
    """
}