process BIOPAX_PARSER {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }"


    input:
    tuple val(meta), path(network)
    val idspace
    val add_variants

    output:
    path "*.owl" , emit: biopax
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('graph-tool'), eval('python -c "import graph_tool; print(graph_tool.__version__)" | cut -d" " -f1'), emit: versions_graphtool, topic: versions
    tuple val("${task.process}"), val('pybiopax'), eval('python -c "import pybiopax; print(pybiopax.__version__)"'), emit: versions_pybiopax, topic: versions
    tuple val("${task.process}"), val('requests'), eval('python -c "import requests; print(requests.__version__)"'), emit: versions_requests, topic: versions

    script:
    """
    gt2biopax.py $network -i $idspace -l DEBUG ${add_variants ? '-v' : ''}
    """
}
