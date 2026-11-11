process INPUTCHECK {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/01/01231a4ef4a2196d65fda042c44442d7b41c3d0859e6766fdfd846f72acfdb23/data'
:         'community.wave.seqera.io/library/modulediscovery_python_dependencies:37beeaac11625203' }" // automatically generated

    input:
    tuple val(meta ), path (seeds, stageAs: 'check/*'), path(network, stageAs: 'check/*')

    output:
    tuple val(meta), path("${meta.id}.tsv")        , emit: seeds, optional: true
    tuple val(meta), path("${meta.id}.no_tool.gt") , emit: seeds_module, optional: true
    tuple val(meta), path("${meta.id}.removed.tsv"), emit: removed_seeds, optional: true
    tuple val(meta), path("${meta.id}.multiqc.tsv"), emit: multiqc
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    input_check.py -s $seeds -p $meta.id -n $network -l DEBUG

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | sed 's/Python //g')"
        graph-tool: "\$(python -c "import graph_tool; print(graph_tool.__version__)" | cut -d' ' -f1)"
    END_VERSIONS
    """
}
