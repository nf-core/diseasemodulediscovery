process DRUGPREDICTIONS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

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
    path "versions.yml"                                                        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def drugstone_id_space = "${idspace}" == "ensembl" ? "ensg" : "${idspace}"
    """
    drug_predictions.py --idspace "${drugstone_id_space}" -p "${meta.id}" -a "${algorithm}" --includeIndirectDrugs ${includeIndirectDrugs} --includeNonApprovedDrugs ${includeNonApprovedDrugs} --result_size "${result_size}" "${module}" -l DEBUG

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | sed 's/Python //g')"
        pandas: "\$(python -c "import pandas; print(pandas.__version__)")"
        drugstone: "\$(pip show drugstone | grep Version | awk '{print \$2}')"
    END_VERSIONS
    """
}
