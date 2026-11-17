process VISUALIZEMODULESDRUGS {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

    input:
    tuple val(meta), path(module), path(drug_predictions)

    output:
    tuple val(meta), path("${meta.id}.pdf")  , emit: pdf
    tuple val(meta), path("${meta.id}.png")  , emit: png
    tuple val(meta), path("${meta.id}.svg")  , emit: svg
    tuple val(meta), path("${meta.id}.html") , emit: html
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    visualize_modules.py -m "${module}" -p "${meta.id}" -d ${drug_predictions} -l DEBUG

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | sed 's/Python //g')"
        graph-tool: "\$(python -c "import graph_tool; print(graph_tool.__version__)" | cut -d' ' -f1)"
        networkx: "\$(python -c "import networkx; print(networkx.__version__)")"
        pyintergraph: "\$(pip show pyintergraph | grep '^Version:' | awk '{print \$2}')"
        pyvis: "\$(pip show pyvis | grep '^Version:' | awk '{print \$2}')"
    END_VERSIONS
    """
}
