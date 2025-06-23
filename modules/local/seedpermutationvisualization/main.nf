process SEEDPERMUTATIONVISUALIZATION {
    label 'process_single'

    input:
    val  (seed_ids)
    val  (network_ids)
    val  (amim_ids)
    path (inputs)

    output:
    path ("seed_rediscovery.*.png")
    path ("seed_rediscovery.*.pdf")
    path ("seed_rediscovery.*.tsv")

    when:
    task.ext.when == null || task.ext.when

    script:
    def concatenated_seed_ids = seed_ids.join(" ")
    def concatenated_network_ids = network_ids.join(" ")
    def concatenated_amim_ids = amim_ids.join(" ")
    """
    seed_permutation_visualization.py \\
        --seed-ids ${concatenated_seed_ids} \\
        --network-ids ${concatenated_network_ids} \\
        --amim-ids ${concatenated_amim_ids} \\
        --inputs ${inputs} \\
        --log-level DEBUG
    """
}
