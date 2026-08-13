
process SEEDPERTURBATION {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "modulediscovery_python_dependencies:894e0b47d51d9d4b" // automatically generated

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
