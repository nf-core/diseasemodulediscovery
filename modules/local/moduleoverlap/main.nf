process MODULEOVERLAP {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

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
