process ROBUSTBIASAWARE {
    tag "$meta.id"
    label 'process_low'
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/4b/4b151131c90d219fcc7c7a0c2b83149cff2cdaefa61a99882d32cc0b2439d671/data'
:         'community.wave.seqera.io/library/robust_bias_aware:cc068c0e1d52ce0e' }" // automatically generated

    input:
    tuple val(meta), path(seeds), path (network)
    val idspace

    output:
    tuple val(meta), path("${meta.id}.graphml")  , emit: module
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('robust-bias-aware'), eval("pip show robust-bias-aware | sed -n 's/^Version: //p'"), emit: versions_robustbiasaware, topic: versions
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
    """
}
