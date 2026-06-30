
process SEEDPERTURBATIONEVALUATION {
    tag "$meta.id"
    label 'process_single'

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
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
