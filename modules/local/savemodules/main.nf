process SAVEMODULES {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

    input:
    tuple val(meta), path(module)

    output:
    tuple val(meta), path("${meta.id}.graphml")  , emit: graphml
    tuple val(meta), path("${meta.id}.nodes.tsv"), emit: nodes_tsv
    tuple val(meta), path("${meta.id}.edges.tsv"), emit: edges_tsv
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('graph-tool'), eval('python -c "import graph_tool; print(graph_tool.__version__)" | cut -d" " -f1'), emit: versions_graphtool, topic: versions
    tuple val("${task.process}"), val('pandas'), eval('python -c "import pandas; print(pandas.__version__)"'), emit: versions_pandas, topic: versions

    script:
    """
    save_modules.py -m "${module}" -p "${meta.id}" -l DEBUG
    """
}
