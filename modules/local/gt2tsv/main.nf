process GT2TSV {
    tag "$meta.id"
    label 'process_single'
    input:
    tuple val(meta), path(gt_file)

    output:
    tuple val(meta), path("${meta.id}.nodes.tsv")        , emit: all_nodes
    tuple val(meta), path("${meta.id}.added_nodes.tsv")  , emit: added_nodes, optional: true

    script:
    """
    gt_to_tsv.py --input $gt_file --output ${meta.id}.nodes.tsv
    gt_to_tsv.py --input $gt_file --output ${meta.id}.added_nodes.tsv --exclude_seeds
    """
}
