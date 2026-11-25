process VISUALIZEMODULES {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

    input:
    tuple val(meta), path(module)

    output:
    tuple val(meta), path("${meta.id}.pdf")      , emit: pdf  , optional: true
    tuple val(meta), path("${meta.id}.png")      , emit: png  , optional: true
    tuple val(meta), path("${meta.id}.svg")      , emit: svg  , optional: true
    tuple val(meta), path("${meta.id}.html")     , emit: html , optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('graph-tool'), eval('python -c "import graph_tool; print(graph_tool.__version__)" | cut -d" " -f1'), emit: versions_graphtool, topic: versions
    tuple val("${task.process}"), val('networkx'), eval('python -c "import networkx; print(networkx.__version__)"'), emit: versions_networkx, topic: versions
    tuple val("${task.process}"), val('pyintergraph'), eval("pip show pyintergraph | sed -n 's/^Version: //p'"), emit: versions_pyintergraph, topic: versions
    tuple val("${task.process}"), val('pyvis'), eval("pip show pyvis | sed -n 's/^Version: //p'"), emit: versions_pyvis, topic: versions

    script:
    """
    visualize_modules.py -m "${module}" -p "${meta.id}" -l DEBUG
    """
}
