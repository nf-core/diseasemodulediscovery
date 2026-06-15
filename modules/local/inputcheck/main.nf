process INPUTCHECK {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta ), path (seeds, stageAs: 'check/*'), path(network, stageAs: 'check/*'), path(blacklist)

    output:
    tuple val(meta), path("${meta.id}.tsv")        , emit: seeds, optional: true
    tuple val(meta), path("${meta.id}.no_tool.gt") , emit: seeds_module, optional: true
    tuple val(meta), path("${meta.id}.removed.tsv"), emit: removed_seeds, optional: true
    tuple val(meta), path("${meta.id}.multiqc.tsv"), emit: multiqc
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def blacklist_arg = blacklist.name != 'NO_FILE' ? "-b ${blacklist}" : ""
    """
    input_check.py -s $seeds -p $meta.id -n $network $blacklist_arg -l DEBUG

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        graph-tool: \$(python -c "import graph_tool; print(graph_tool.__version__)")
    END_VERSIONS
    """
}
