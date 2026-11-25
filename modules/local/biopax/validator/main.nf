process BIOPAX_VALIDATOR {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/da/daf717f9ae2604fcfee3b28c493ee67554b40ebd05e13837ca4fe607f9044703/data'
        : 'community.wave.seqera.io/library/biopax-validator:ec92f1efa2d11d2e'}" // automatically generated

    input:
    path biopax_files
    val validate_online

    output:
    path "biopax-validator-report.html", emit: validation
    tuple val("${task.process}"), val('openjdk'), eval("java -version 2>&1 | head -n1 | cut -d'\"' -f2 | cut -d'-' -f1"), emit: versions_openjdk, topic: versions
    // the tool has no version flag, so the version is taken from its conda share directory name
    tuple val("${task.process}"), val('biopax-validator'), eval('ls $(dirname $(readlink -f $(which biopax-validator)))/../share | sed -n "s/^biopax-validator-//p"'), emit: versions_biopaxvalidator, topic: versions

    script:
    """

    if [ "${validate_online}" = true ]; then
        echo "Validating online"
        biopax-validator-client . biopax-validator-report.html notstrict
    else
        echo "Validating offline"
        # the wrapper sets the Spring agent and --add-opens flags, extra JVM options go through JAVA_OPTS
        export JAVA_OPTS="-Xmx${task.memory.toGiga().toInteger()}g -Djava.security.egd=file:/dev/./urandom"
        biopax-validator . --output=biopax-validator-report.html --profile=notstrict
    fi
    """
}
