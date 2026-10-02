
// Many additional examples for nextflow modules are available at https://github.com/nf-core/modules/tree/master/modules/nf-core

process DIAMOND {                           // Process name, should be all upper case
    tag "$meta.id"                          // Used to display the process in the progress overview
    label 'process_low'                     // Used to allocate resources; see conf/base.config for label-specific settings

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

    input:                                            // Define the input channels
    tuple val(meta), path(seeds), path (network)      // Paths to seeds file and network file
    val n                                             // DIAMOnD specific parameter "n"
    val alpha                                         // DIAMOnD spefific parameter "alpha"

    output:                                 // Define output files, "emit" is only used to access the corresponding outputs externally
    tuple val(meta), path("${meta.id}.first_${n}_added_nodes_weight_${alpha}.txt")   , emit: module       // Define a pattern for the output file (can also be the full name, if known), emit -> the active module
    path "versions.yml"                                                              , emit: versions     // Software versions, this is not essential but nice, the collected versions will be part of the final multiqc report

    when:
    task.ext.when == null || task.ext.when  // Allows to prevent the execution of this process via a workflow logic, just put it in

    // The script for executing DIAMOnD, which is vendored in bin/ and therefore on the PATH
    // Access inputs, parameters, etc. with the "$" operator
    // The part starting with "cat <<-END_VERSIONS > versions.yml" only collects software versions for the versions.yml file, not essential
    script:
    """
    # DIAMOnD breaks ties between equally scoring nodes via set iteration order, which
    # depends on the hash seed. Fix it so the reported ranks are reproducible.
    export PYTHONHASHSEED=0

    DIAMOnD.py \\
        $network \\
        $seeds \\
        $n \\
        $alpha \\
        ${meta.id}.first_${n}_added_nodes_weight_${alpha}.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | sed 's/Python //g')"
        networkx: "\$(python -c "import networkx; print(networkx.__version__)")"
        scipy: "\$(python -c "import scipy; print(scipy.__version__)")"
        numpy: "\$(python -c "import numpy; print(numpy.__version__)")"
    END_VERSIONS
    """
}
