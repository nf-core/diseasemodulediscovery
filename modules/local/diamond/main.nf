
// Many additional examples for nextflow modules are available at https://github.com/nf-core/modules/tree/master/modules/nf-core

process DIAMOND {                           // Process name, should be all upper case
    tag "$meta.id"                          // Used to display the process in the progress overview
    label 'process_low'                     // Used to allocate resources; see conf/base.config for label-specific settings

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/49/49f3bf62ff66b8c76807029ac4b555fb3d111326d258ac40b66d906136a9ca7c/data'
        : 'community.wave.seqera.io/library/modulediscovery_python_dependencies:0ba80986ead7e04c'}" // automatically generated

    input:                                            // Define the input channels
    tuple val(meta), path(seeds), path (network)      // Paths to seeds file and network file
    val n                                             // DIAMOnD specific parameter "n"
    val alpha                                         // DIAMOnD spefific parameter "alpha"

    output:                                 // Define output files, "emit" is only used to access the corresponding outputs externally
    tuple val(meta), path("${meta.id}.first_${n}_added_nodes_weight_${alpha}.txt")   , emit: module       // Define a pattern for the output file (can also be the full name, if known), emit -> the active module
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('networkx'), eval('python -c "import networkx; print(networkx.__version__)"'), emit: versions_networkx, topic: versions
    tuple val("${task.process}"), val('scipy'), eval('python -c "import scipy; print(scipy.__version__)"'), emit: versions_scipy, topic: versions
    tuple val("${task.process}"), val('numpy'), eval('python -c "import numpy; print(numpy.__version__)"'), emit: versions_numpy, topic: versions

    // The script for executing DIAMOnD, which is vendored in bin/ and therefore on the PATH
    // Access inputs, parameters, etc. with the "$" operator
    script:
    """
    DIAMOnD.py \\
        $network \\
        $seeds \\
        $n \\
        $alpha \\
        ${meta.id}.first_${n}_added_nodes_weight_${alpha}.txt
    """
}
