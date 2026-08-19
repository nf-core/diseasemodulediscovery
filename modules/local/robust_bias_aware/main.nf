process ROBUSTBIASAWARE {
    tag "$meta.id"
    label 'process_low'
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/a9/a99e4719bc4bf4c1cb5af87ec9dc3d87069d49c4ae3b3ade730b14e231966c7e/data'
:         'community.wave.seqera.io/library/robust_bias_aware:e9adb1fd9f1376ff' }" // automatically generated

    input:
    tuple val(meta), path(seeds), path (network)
    val idspace

    output:
    tuple val(meta), path("${meta.id}.graphml")  , emit: module
    path "versions.yml"     , emit: versions
    when:
    task.ext.when == null || task.ext.when
    script:
    def args = task.ext.args ?: ''          // Get possible alpha, beta, n, and tau arguments for robust, see TODO above
    def identifier ="${idspace}" == "SYMBOL" ? "GENE_SYMBOL":
                    "${idspace}" == "ENTREZ" ? "${idspace}":
                    "${idspace}" == "UNIPROT" ? "${idspace}":""
    if(identifier == ""){
        log.warn("provided identifier ${idspace} not supported with robust_bias_aware, default GENE_SYMBOL will be used")
        identifier = "GENE_SYMBOL"
    }
    """
    robust-bias-aware --seeds $seeds --outfile "${meta.id}.graphml" --namespace $identifier --network $network  $args
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | sed 's/Python //g')"
        robust-bias-aware: "\$(pip show robust-bias-aware | grep Version | awk '{print \$2}')"
    END_VERSIONS
    """
}
