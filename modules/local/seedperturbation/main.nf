
process SEEDPERTURBATION {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(seeds)

    output:
    tuple val(meta), path("${meta.seeds_id}.*.${seeds.extension}") , emit: perturbed_seeds
    path "versions.yml"                                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ? task.ext.args : ""
    def leave_x_out = params.leave_frac_out_perturbation ? "--leave_x_out" : ""
    """
    seed_perturbation.py ${args} --seeds ${seeds} --prefix ${meta.seeds_id} ${leave_x_out} --frac ${params.fraction} --n ${params.n_leave_frac_out}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}
