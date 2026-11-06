process BIOPAX_PARSER {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }"


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
        python: "\$(python --version | sed 's/Python //g')"
        graph-tool: "\$(python -c "import graph_tool; print(graph_tool.__version__)" | cut -d' ' -f1)"
        pybiopax: "\$(python -c "import pybiopax; print(pybiopax.__version__)")"
        nedrex: "\$(python -c "import nedrex; print(nedrex.__version__)")"
    END_VERSIONS
    """
}
