
process DOMINO_DOMINO {     // Process name, should be all upper case. Only the part before "_" will be used to define the output folder
    tag "$meta.id"
    label 'process_high'     // Used to allocate resources, "process_high" defines this process resource class; for more labels see conf/base.config
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
?         'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/d1/d1e127804ca623639fc35b159206b564f3cc3e579ac1cad595c8a84d40609be5/data'
:         'community.wave.seqera.io/library/domino:d7848ba6939a9ab0' }"   // The preferred way to two define a container, if a biocontainer is available

    input:
    tuple val(meta), path(seeds), path (network), path(slices)

    output:                                                                       // Define the expected outputs, the "emit:" keyword defines, how the output can be accessed by other processes
    tuple val(meta), path("${seeds.baseName}/modules.out")  , emit: modules       // DOMINO will place a modules.out file in a folder, named as the seed gene file
    path "versions.yml"                                     , emit: versions      // The software versions, in this case it is only the python version


    when:
    task.ext.when == null || task.ext.when

    // Run DOMINO, it supports muliple threads, which are set using the "label" keyword and accessed using $task.cpus
    script:
    def args = task.ext.args ?: ''          // Get possible optional arguments (e.g. turning off visualization, see conf/modules.config)
    """
    domino \\
    $args \\
    -p $task.cpus \\
    -a $seeds \\
    -n $network \\
    -s $slices \\
    -o .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: "\$(python --version | sed 's/Python //g')"
        domino: "\$(python -c "import json,importlib.metadata as m; u=json.loads(m.distribution('domino-python').read_text('direct_url.json'))['url']; print(u.rsplit('/',1)[-1].removeprefix('v').removesuffix('.tar.gz'))")"
        pcst-fast: "\$(pip show pcst-fast | grep '^Version:' | awk '{print \$2}')"
        statsmodels: "\$(pip show statsmodels | grep '^Version:' | awk '{print \$2}')"
        networkx: "\$(pip show networkx | grep '^Version:' | awk '{print \$2}')"
        scipy: "\$(pip show scipy | grep '^Version:' | awk '{print \$2}')"
        numpy: "\$(pip show numpy | grep '^Version:' | awk '{print \$2}')"
    END_VERSIONS
    """
}
