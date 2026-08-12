process BIOPAX_PARSER {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2d/2dc099c6561d0c857b4673ac4077adee0de873e76300cbdc51e28856179f4eae/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:894e0b47d51d9d4b' }"


    input:
    tuple val(meta), path(network)
    val idspace
    val add_variants

    output:
    path "*.owl" , emit: biopax
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    gt2biopax.py $network -i $idspace -l DEBUG ${add_variants ? '-v' : ''}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        graph-tool: \$(python -c "import graph_tool; print(graph_tool.__version__)" | cut -d' ' -f1)
        pybiopax: \$(python -c "import pybiopax; print(pybiopax.__version__)")
        nedrex: \$(python -c "import nedrex; print(nedrex.__version__)")
    END_VERSIONS
    """
}
