process HIERARCHICAL_HOTNET_SCORE_PARSER {
    tag "$meta.id"
    label 'process_single'

    input:
    tuple val(meta), path(seeds), path(node_list)
    output:
    tuple val(meta), path("*.node_scores.tsv")

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    awk 'NR==FNR{a[\$1]=1; next} {print \$2"\t"(a[\$2]?1:0)}' "${seeds}" "${node_list}" > "${meta.id}.node_scores.tsv"
    """
}
