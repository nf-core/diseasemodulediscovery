process HIERARCHICAL_HOTNET_PERMUTE_SCORES {
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0f/0ff202606a65efc9b3c4898270051a4caaf044a3c2550831a4e1f79dce421bca/data'
        : 'community.wave.seqera.io/library/hierarchical_hotnet:8bea4d8e8f9b32f2'}"

    input:
    tuple val(meta), path(node_list), path(edge_list), path(node_scores)
    val(num_permutations)
    output:
    tuple val(meta), path("${meta.id}.score_permutation*"), emit: permuted_scores
    path "versions.yml"                                , emit: versions
    when:
    task.ext.when == null || task.ext.when

    script:
    """
    python ${projectDir}/bin/hierarchical_hotnet/find_permutation_bins.py \
        -gsf ${node_scores} \
        -igf ${node_list} \
        -elf ${edge_list} \
        -o ${meta.id}.score_bins.tsv

    for i in `seq $num_permutations`
    do
        python ${projectDir}/bin/hierarchical_hotnet/permute_scores.py \
            -i ${node_scores} \
            -bf ${meta.id}.score_bins.tsv \
            -s \$i \
            -o ${meta.id}.score_permutation_\$i.tsv
    done
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version 2>&1 | sed 's/Python //g')
        networkX: \$(python -c "import networkx; print(networkx.__version__)")
        numpy: \$(python -c "import numpy; print(numpy.__version__)")
        scipy: \$(python -c "import scipy; print(scipy.__version__)")
    END_VERSIONS
    """

}
