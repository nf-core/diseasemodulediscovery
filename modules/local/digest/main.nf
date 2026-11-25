process DIGEST {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/biodigest:0.2.16--pyhdfd78af_2'

    input:
    tuple val(meta), path(target_file)
    val target_type
    path network
    val network_type
    val mode

    output:
    tuple val(meta), path("${meta.id}")            , emit: outdir
    tuple val(meta), path("${meta.id}.multiqc.tsv"), emit: multiqc, optional: true
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('biodigest'), eval("pip show biodigest | sed -n 's/^Version: //p'"), emit: versions_biodigest, topic: versions
    tuple val("${task.process}"), val('pandas'), eval('python -c "import pandas; print(pandas.__version__)"'), emit: versions_pandas, topic: versions
    tuple val("${task.process}"), val('numpy'), eval('python -c "import numpy; print(numpy.__version__)"'), emit: versions_numpy, topic: versions

    script:
    """
    digest.py --target_file $target_file  --target_type $target_type   --network $network  --network_type $network_type --mode $mode --outdir ${meta.id}
    """
}
