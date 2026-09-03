
process DOMINO_SLICER {             // Process name, should be all upper case. Only the part before "_" will be used to define the output folder
    tag "$meta.id"
    label 'process_low'          // Used to allocate resources; see conf/base.config for label definitions
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/d1/d1e127804ca623639fc35b159206b564f3cc3e579ac1cad595c8a84d40609be5/data'
:         'community.wave.seqera.io/library/domino:d7848ba6939a9ab0' }" // The preferred way to two define a container, if a biocontainer is available

    input:
    tuple val(meta), path (network)                       // The input network

    output:                                                // Define the expected outputs, the "emit:" keyword defines, how the output can be accessed by other processes
    tuple val(meta), path("${meta.id}.slices.txt"), emit: slices
    path "versions.yml"                           , emit: versions


    when:
    task.ext.when == null || task.ext.when


    // The script for executing slicer
    // Access inputs, parameters, etc. with the "$" operator
    // The part starting with "cat <<-END_VERSIONS > versions.yml" only collects software versions for the versions.yml file, not essential
    script:
    """
    slicer -n $network -o ${meta.id}.slices.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | sed 's/Python //g')"
        domino: "\$(python -c "import json,importlib.metadata as m; u=json.loads(m.distribution('domino-python').read_text('direct_url.json'))['url']; print(u.rsplit('/',1)[-1].removeprefix('v').removesuffix('.tar.gz'))")"
        python-louvain: "\$(pip show python-louvain | grep '^Version:' | awk '{print \$2}')"
        networkx: "\$(pip show networkx | grep '^Version:' | awk '{print \$2}')"
        numpy: "\$(pip show numpy | grep '^Version:' | awk '{print \$2}')"
    END_VERSIONS
    """
}
