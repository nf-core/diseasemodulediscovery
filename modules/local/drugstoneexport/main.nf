process DRUGSTONEEXPORT{
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "modulediscovery_python_dependencies:894e0b47d51d9d4b" // automatically generated

    input:
    tuple val(meta), path(module)
    val(id_space)

    output:
    tuple val(meta), path("${meta.id}.drugstonelink.tsv")   , emit: link
    path "versions.yml"     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    drugstone_export.py -m $module -i $id_space -p "${meta.id}"
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        graph-tool: \$(python -c "import graph_tool; print(graph_tool.__version__)" | cut -d' ' -f1)
    END_VERSIONS
    """
}
