process NETWORKANNOTATION {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

    input:
    tuple val(meta), path(subnetwork, stageAs: 'input/*'), path(network, stageAs: 'input/*')

    output:
    tuple val(meta), path("${meta.id}.gt"), emit: module
    path "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    network_annotation.py -s $subnetwork -n $network -o ""${meta.id}.gt""

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | sed 's/Python //g')"
        graph-tool: "\$(python -c "import graph_tool; print(graph_tool.__version__)" | cut -d' ' -f1)"
    END_VERSIONS
    """
}
