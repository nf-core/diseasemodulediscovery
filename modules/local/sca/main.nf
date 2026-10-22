process SCA{
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/d8/d833535377b556a1ff9d58d57e45fa1c488b56ba5fa7e0b9fb4da3eb670d6610/data'
:         'community.wave.seqera.io/library/sca:94730ae961d2eb6d' }" // automatically generated

    input:
    tuple val(meta), path(seeds), path (network)

    output:
    tuple val(meta), path("Predicted_genelist.txt")   , emit: module
    path "versions.yml"                               , emit: versions


    when:
    task.ext.when == null || task.ext.when

    script:
    """
    SCA2024.py $network $seeds
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
