process DIGEST_DIGEST {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/d1/d1934dcbe8ceb3238dd78695d37fe3a7eefe5137900035c88d0aaea55fcab696/data'
        : 'community.wave.seqera.io/library/digest:98f5b31fccdef4bf'}" // automatically generated

    input:
    tuple val(meta), path(target_file)
    val target_type
    path network
    val network_type
    path mapping_files
    val mode

    output:
    tuple val(meta), path("${meta.id}")            , emit: outdir
    tuple val(meta), path("${meta.id}.multiqc.tsv"), emit: multiqc, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('biodigest'), eval("python -c \"from importlib.metadata import version; print(version('biodigest'))\""), emit: versions_biodigest, topic: versions
    tuple val("${task.process}"), val('pandas'), eval('python -c "import pandas; print(pandas.__version__)"'), emit: versions_pandas, topic: versions
    tuple val("${task.process}"), val('numpy'), eval('python -c "import numpy; print(numpy.__version__)"'), emit: versions_numpy, topic: versions

    script:
    """
    digest.py --target_file $target_file  --target_type $target_type   --network $network  --network_type $network_type --mode $mode --mapping_dir $mapping_files --outdir ${meta.id}
    """
}
