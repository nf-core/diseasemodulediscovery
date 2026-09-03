process MODULEOVERLAP {
    label 'process_single'

    input:
    val(ids)
    path(inputs)

    output:
    path('jaccard_similarity_matrix_mqc.tsv')           , emit: jaccard_multiqc
    path('shared_nodes_matrix_mqc.tsv')                 , emit: shared_multiqc
    path('jaccard_similarity_no_seeds_matrix_mqc.tsv')  , emit: jaccard_no_seeds_multiqc, optional: true
    path('shared_nodes_no_seeds_matrix_mqc.tsv')        , emit: shared_no_seeds_multiqc, optional: true

    script:
    def concatenated_ids = ids.join(" ")
    """
    module_overlap.py --ids $concatenated_ids --inputs $inputs
    """
}
