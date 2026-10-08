
process ROBUST {
    tag "$meta.id"
    label 'process_low'
    container 'docker.io/kerstingjohannes/robust:1.0.0-e8861de'

    input:
    tuple val(meta), path(seeds), path (network)
    // TODO: check whether the values in args should be converted to nextflow values and set defaults via nextflow

    output:
    tuple val(meta), path("${meta.id}.graphml")  , emit: module
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''          // Get possible alpha, beta, n, and tau arguments for robust, see TODO above
    """
    python3 /robust/robust.py \\
        $network \\
        $seeds \\
        "${meta.id}.graphml" \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python3 --version | sed 's/Python //g')"
        pcst-fast: "\$(python3 -c "from importlib.metadata import version; print(version('pcst_fast'))")"
        networkx: "\$(python3 -c "import networkx; print(networkx.__version__)")"
        numpy: "\$(python3 -c "import numpy; print(numpy.__version__)")"
    END_VERSIONS
    """
}
