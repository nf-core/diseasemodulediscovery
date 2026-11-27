process DRUGPREDICTIONS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/49/49f3bf62ff66b8c76807029ac4b555fb3d111326d258ac40b66d906136a9ca7c/data'
        : 'community.wave.seqera.io/library/modulediscovery_python_dependencies:0ba80986ead7e04c'}" // automatically generated

    input:
    tuple val(meta), path(module)
    val idspace
    val algorithm
    val includeIndirectDrugs
    val includeNonApprovedDrugs
    val result_size

    output:
    tuple val(meta), val(algorithm), path("${meta.id}.drug_predictions.tsv")   , emit: drug_predictions
    tuple val(meta), val(algorithm), path("${meta.id}.csv")                    , emit: drugstone_download
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('pandas'), eval('python -c "import pandas; print(pandas.__version__)"'), emit: versions_pandas, topic: versions
    tuple val("${task.process}"), val('drugstone'), eval("pip show drugstone | sed -n 's/^Version: //p'"), emit: versions_drugstone, topic: versions

    script:
    def drugstone_id_space = "${idspace}" == "ensembl" ? "ensg" : "${idspace}"
    """
    drug_predictions.py --idspace "${drugstone_id_space}" -p "${meta.id}" -a "${algorithm}" --includeIndirectDrugs ${includeIndirectDrugs} --includeNonApprovedDrugs ${includeNonApprovedDrugs} --result_size "${result_size}" "${module}" -l DEBUG
    """
}
