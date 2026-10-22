process TOPAS{
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c8ba6ae70658a1ac90aa6631bd8074ffb843b009e49027c6dd807ab24ab035a/data'
:         'community.wave.seqera.io/library/modulediscovery_topas_dependencies:c05c97da1d163962' }" // automatically generated

    input:
    tuple val(meta), path(seeds), path(network)

    output:
    tuple val(meta), path("${meta.id}.topas.txt")   , emit: module
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    run_topas.R -n $network -s $seeds -o ${meta.id}.topas.txt
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        R: \$(R --version | grep "^R version" | cut -d " " -f1-3)
    END_VERSIONS
    """
}
