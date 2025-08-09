process DOWNLOADDRUGLIST {
    label 'process_single'
    tag   'download_drug_list'

    input:
      val collection

    output:
      path "${collection}.csv", emit: csv_out

    script:
    """
    #!/usr/bin/env bash

    # 1) Choose endpoint based on license acceptance
    BASE_URL='${ params.accept_license ? "https://api.nedrex.net/licensed/" : "https://api.nedrex.net/open/" }'

    # 2) Conditionally generate API key
    if [ "${params.accept_license}" = "true" ]; then
      api_key=\$(generate_NEDREX_API_key.py \
        --base-url "\$BASE_URL" \
        --print-key)
    fi

    # 3) Download drug list
    nedrex_node_extraction.py \
      --base-url "\$BASE_URL" \
      --collections "$collection" \
      --output ./ \
      ${ params.accept_license ? '--api-key "\$api_key"' : '' }
    """
}

process PRIORITIZATIONEVALUATION {

  tag "$meta.id"
  label 'process_single'

  publishDir "${params.outdir}/prioritizationevaluation",
             mode: 'copy',
             overwrite: true,
             pattern: "*.prioritization_evaluation.tsv"

  input:
    tuple val(meta), val(algorithm), path(prediction_file), path(true_drugs)
    path  drug_csv

  output:
    tuple val(meta), val(algorithm), path("${meta.id}.prioritization_evaluation.tsv"), emit: prioritization_evaluation
  script:
  """
  drug_validation.py \
      --candidate-drugs ${prediction_file} \
      --drug-list       ${drug_csv} \
      --true-drugs      ${true_drugs} \
      --out-dir         . \
      --permutation-count ${params.eval_permutations} \
      ${params.includeNonApprovedDrugs ? '' : '--only-approved'} \
      --output-file     ${meta.id}.prioritization_evaluation.tsv
  """
}