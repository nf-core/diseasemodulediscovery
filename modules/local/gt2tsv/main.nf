process GT2TSV {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "modulediscovery_python_dependencies:894e0b47d51d9d4b" // automatically generated

    input:
    tuple val(meta), path(gt_file)

    output:
    tuple val(meta), path("${meta.id}.nodes.tsv")

    script:
    """
    gt_to_tsv.py --input $gt_file  --output ${meta.id}.nodes.tsv
    """
}
