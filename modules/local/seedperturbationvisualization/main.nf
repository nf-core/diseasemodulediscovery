process SEEDPERTURBATIONVISUALIZATION {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

    input:
    val  (seed_ids)
    val  (network_ids)
    val  (amim_ids)
    path (inputs)

    output:
    path ("*.seed_rediscovery.png")
    path ("*.seed_rediscovery.pdf")
    path ("*.seed_rediscovery.tsv")
    path ("*.robustness.png")
    path ("*.robustness.pdf")
    path ("*.robustness.tsv")

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def concatenated_seed_ids = seed_ids.join(" ")
    def concatenated_network_ids = network_ids.join(" ")
    def concatenated_amim_ids = amim_ids.join(" ")
    """
    seed_perturbation_visualization.py \\
        --seed-ids ${concatenated_seed_ids} \\
        --network-ids ${concatenated_network_ids} \\
        --amim-ids ${concatenated_amim_ids} \\
        --inputs ${inputs} \\
        ${args}
    """
}
