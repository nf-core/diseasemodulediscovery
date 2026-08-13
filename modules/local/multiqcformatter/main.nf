process MULTIQCFORMATTER {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "modulediscovery_python_dependencies:894e0b47d51d9d4b" // automatically generated

    input:
    tuple path(header), path(inputFiles, stageAs: 'input/*')
    output:
    path("*mqc*")       , emit : multiqc
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when
    script:
    """
    multiqc_formatter.py -i $inputFiles -H $header
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | sed 's/Python //g')"
    END_VERSIONS
    """

}
