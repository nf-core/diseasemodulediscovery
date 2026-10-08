process PATHWAYFREQUENCY {
    label 'process_single'

    input:
    val(ids)
    path(list_enriched_pathways)

    output:
    path('<source>_terms_frequency_in_modules.tsv')             , emit: <source>_pathways_frequency_multiqc
    // <source> = the sources found in the *.gprofiler2.all_enriched_pathways.tsv file
    path('upset_pathway_frequency_multiqc.png')                 , emit: png_pathways_frequency_multiqc
    path('upset_pathway_frequency_multiqc.pdf')                 , emit: pdf_pathways_frequency_multiqc

    script:
    def concatenated_ids = ids.join(" ")
    """
    pathway_frequency.py --ids $concatenated_ids --list_enriched_pathways $list_enriched_pathways
    """
}