
process SEEDPERTURBATIONEVALUATION {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

    input:
    tuple val(meta), path(module)
    path(seeds)
    path(perturbed_modules)
    path(perturbed_seeds)
    path(network)

    output:
    tuple val(meta), path("${meta.id}.seed_perturbation_evaluation_summary.tsv")  , emit: summary
    tuple val(meta), path("${meta.id}.seed_perturbation_evaluation_detailed.tsv") , emit: detailed
    tuple val(meta), path("${meta.id}.seed_perturbation_multiqc_summary.tsv")     , emit: multiqc_summary
    tuple val(meta), path("${meta.id}.seed_perturbation_multiqc_jaccard.txt")     , emit: multiqc_jaccard
    path "versions.yml"                                                          , emit: versions

    when:
    task.ext.when == null || task.ext.when


    script:
    """
    seed_perturbation_evaluation.py \\
        --prefix ${meta.id} \\
        --module ${module} \\
        --seeds ${seeds} \\
        --perturbed_modules ${perturbed_modules} \\
        --perturbed_seeds ${perturbed_seeds} \\
        --network ${network}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | sed 's/Python //g')"
    END_VERSIONS
    """
}
