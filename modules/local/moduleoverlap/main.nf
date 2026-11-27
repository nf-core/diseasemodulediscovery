process MODULEOVERLAP {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/49/49f3bf62ff66b8c76807029ac4b555fb3d111326d258ac40b66d906136a9ca7c/data'
        : 'community.wave.seqera.io/library/modulediscovery_python_dependencies:0ba80986ead7e04c'}" // automatically generated

    input:
    val(ids)
    path(inputs)

    output:
    path('jaccard_similarity_matrix_mqc.tsv')           , emit: jaccard_multiqc
    path('shared_nodes_matrix_mqc.tsv')                 , emit: shared_multiqc
    path('jaccard_similarity_no_seeds_matrix_mqc.tsv')  , emit: jaccard_no_seeds_multiqc, optional: true
    path('shared_nodes_no_seeds_matrix_mqc.tsv')        , emit: shared_no_seeds_multiqc, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('pandas'), eval('python -c "import pandas; print(pandas.__version__)"'), emit: versions_pandas, topic: versions

    script:
    def concatenated_ids = ids.join(" ")
    """
    module_overlap.py --ids $concatenated_ids --inputs $inputs
    """
}
