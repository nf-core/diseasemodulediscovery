
process RWR {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

    input:
    tuple val(meta), path(seeds), path (network)    // Input files
    val scaling                                     // RWR specific parameter "scaling"
    val symmetrical                                 // RWR spefific parameter "symmetrical"
    val r                                           // RWR specific parameter "r"

    output:
    tuple val(meta), path("*.txt") , emit: module
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('networkx'), eval('python -c "import networkx; print(networkx.__version__)"'), emit: versions_networkx, topic: versions
    tuple val("${task.process}"), val('scipy'), eval('python -c "import scipy; print(scipy.__version__)"'), emit: versions_scipy, topic: versions
    tuple val("${task.process}"), val('numpy'), eval('python -c "import numpy; print(numpy.__version__)"'), emit: versions_numpy, topic: versions

    script:
    """
    rwr.py \\
        $network \\
        $seeds \\
        $scaling \\
        $symmetrical \\
        $r
    """
}
