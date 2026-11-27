process MULTIQCFORMATTER {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/49/49f3bf62ff66b8c76807029ac4b555fb3d111326d258ac40b66d906136a9ca7c/data'
        : 'community.wave.seqera.io/library/modulediscovery_python_dependencies:0ba80986ead7e04c'}" // automatically generated

    input:
    tuple path(header), path(inputFiles, stageAs: 'input/*')
    output:
    path("*mqc*")       , emit : multiqc
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('pyyaml'), eval('python -c "import yaml; print(yaml.__version__)"'), emit: versions_pyyaml, topic: versions

    script:
    """
    multiqc_formatter.py -i $inputFiles -H $header
    """

}
