process GENEFREQUENCY {
    label 'process_single'

    input:
    val(ids)
    path(original_modules_files)
    path(permuted_PPI_modules_files)
    path(removed_seed_modules_files)

    output:
    path('gene_frequency_in_modules.tsv')           , emit: gene_frequency_multiqc
    path('upset_gene_frequency.png')                , emit: upset_png_gene_frequency_multiqc
    path('upset_gene_frequency.pdf')                , emit: upset_pdf_gene_frequency_multiqc

    script:
    def concatenated_ids = ids.join(" ")
    """
    gene_frequency.py --ids $concatenated_ids --original_modules $original_modules_files --permuted_PPI_modules $permuted_PPI_modules_files --removed_seed_modules $removed_seed_modules_files
    """
}
