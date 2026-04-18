process MULTIQCFORMATTER {
    label 'process_single'

    input:
    tuple path(header), path(inputFiles)
    output:
    path("*mqc*"), emit : multiqc
    path "versions.yml"               , emit: versions

    when:
    task.ext.when == null || task.ext.when
    script:
    """
    multiqc_formatter.py -i $inputFiles -H $header
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        graph-tool: \$(python -c "import graph_tool; print(graph_tool.__version__)")
    END_VERSIONS
    """

}
