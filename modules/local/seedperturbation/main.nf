
process SEEDPERTURBATION {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

    input:
    tuple val(meta), path(seeds)

    output:
    tuple val(meta), path("${meta.seeds_id}.*.${seeds.extension}") , emit: perturbed_seeds
    path "versions.yml"                                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    seed_perturbation.py --seeds ${seeds} --prefix ${meta.seeds_id}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python3 --version | sed 's/Python //g')"
    END_VERSIONS
    """
}
