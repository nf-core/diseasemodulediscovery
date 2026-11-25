
process ROBUST {
    tag "$meta.id"
    label 'process_low'
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/cb/cba1bc45713a153a51cb10a8d34edc68e506a4d47d108db0726aa560ba9c41e1/data'
:         'community.wave.seqera.io/library/robust:6a0d16d512611aaa' }" // automatically generated

    input:
    tuple val(meta), path(seeds), path (network)

    output:
    tuple val(meta), path("${meta.id}.graphml")  , emit: module
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('robust-pcst'), eval("python -c \"from importlib.metadata import version; print(version('robust-pcst'))\""), emit: versions_robustpcst, topic: versions

    script:
    def args = task.ext.args ?: ''          // Initial fraction, reduction factor, number of trees, and threshold
    """
    robust-pcst \\
        $network \\
        $seeds \\
        "${meta.id}.graphml" \\
        $args
    """
}
