
process RWR {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "modulediscovery_python_dependencies:894e0b47d51d9d4b" // automatically generated

    input:
    tuple val(meta), path(seeds), path (network)    // Input files
    val scaling                                     // RWR specific parameter "scaling"
    val symmetrical                                 // RWR spefific parameter "symmetrical"
    val r                                           // RWR specific parameter "r"

    output:
    tuple val(meta), path("*.txt") , emit: module
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    rwr.py \\
        $network \\
        $seeds \\
        $scaling \\
        $symmetrical \\
        $r

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
