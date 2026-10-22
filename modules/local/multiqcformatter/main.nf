process MULTIQCFORMATTER {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

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
