process ROBUST {
    tag "$meta.id"
    label 'process_low'
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/1c/1cd575a6e0e48532dba2da91f5f1d435f15c74f82cd3d21088d86210448960a9/data'
        : 'community.wave.seqera.io/library/robust:b45458ff322adfd5'}" // automatically generated

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
