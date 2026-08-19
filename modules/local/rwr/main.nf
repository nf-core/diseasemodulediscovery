
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
        python: "\$(python --version | sed 's/Python //g')"
    END_VERSIONS
    """
}
