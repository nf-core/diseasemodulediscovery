process DOWNLOADDRUGLIST {
    label 'process_single'
    tag   'download_drug_list'

    // Emit the final CSV for downstream channels
    output:
        path 'drug.csv', emit: drug_csv
//       TODO: possibly add ability to specify base url
    script:
    """
    # 1. Generate a fresh API key
    api_key=\$(generate_NEDREX_API_key.py \
        --base-url https://api.nedrex.net/licensed/ \
        --print-key)

    # 2. Download the drug collection using that key
    nedrex_node_extraction.py \
        --base-url https://api.nedrex.net/licensed/ \
        --collections drug \
        --output ./ \
        --api-key "\$api_key"
    """

}
process PRIORITIZATIONEVALUATION {
  tag "$meta.id"
  label 'process_single'
  publishDir "${params.outdir}/prioritizationevaluation",
             mode: 'copy',           // copy rather than move
             overwrite: true,        // overwrite existing files if any
             pattern: "*.prioritization_evaluation.tsv"

  input:
    tuple val(meta), val(algorithm), path(prediction_file)
    path drug_csv
    path true_drugs

  output:
    tuple val(meta), val(algorithm), path("${meta.id}.prioritization_evaluation.tsv"), emit: prioritization_evaluation

  script:
  """
  drug_validation.py \
    --candidate-drugs ${prediction_file} \
    --drug-list      ${drug_csv} \
    --true-drugs     ${true_drugs} \
    --out-dir        . \
    --output-file    ${meta.id}.prioritization_evaluation.tsv
  """
}


