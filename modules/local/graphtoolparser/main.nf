process GRAPHTOOLPARSER {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/49/49f3bf62ff66b8c76807029ac4b555fb3d111326d258ac40b66d906136a9ca7c/data'
        : 'community.wave.seqera.io/library/modulediscovery_python_dependencies:0ba80986ead7e04c'}" // automatically generated

    input:
    tuple val(meta), path(network, stageAs: 'input/*')
    val format

    output:
    tuple val(meta), path("*${format}*")                    , emit: network
    tuple val(meta), path("input_network_multiqc.tsv")      , emit: multiqc     , optional: true
    tuple val(meta), path("*node_degree_distribution.yaml") , emit: node_degree , optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('graph-tool'), eval('python -c "import graph_tool; print(graph_tool.__version__)" | cut -d" " -f1'), emit: versions_graphtool, topic: versions
    tuple val("${task.process}"), val('pyyaml'), eval('python -c "import yaml; print(yaml.__version__)"'), emit: versions_pyyaml, topic: versions

    script:
    """
    graph_tool_parser.py $network -f $format -l DEBUG
    """
}
