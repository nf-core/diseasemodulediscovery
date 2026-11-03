process HIERARCHICAL_HOTNET_PERMUTE_SCORES {
    tag "$meta.id"
    label 'process_single'
    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/d9/d9ad2dd27f50f0e332b61bf6e8e5562d9ef62575bea80abf26a8a0270d87b00a/data'
        : 'community.wave.seqera.io/library/hierarchical_hotnet:9d9481ba9020b769'}"

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
    python -m find_permutation_bins \
        -gsf ${node_scores} \
        -igf ${node_list} \
        -elf ${edge_list} \
        -o ${meta.id}.score_bins.tsv

    for i in `seq $num_permutations`
    do
        python -m permute_scores \
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
