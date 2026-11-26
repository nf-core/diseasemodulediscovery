process DIGEST_SETUP {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/9c/9ca49f3db139438fe5f91446e5dad4024602b0b92c9a25bf7f70d35639a7bc9a/data'
        : 'community.wave.seqera.io/library/digest:fb492089d1f42e56'}" // automatically generated


    output:
    path "mapping_files", emit: mapping_files
    tuple val("${task.process}"), val('python'), eval("python --version | sed 's/Python //g'"), emit: versions_python, topic: versions
    tuple val("${task.process}"), val('biodigest'), eval("python -c \"from importlib.metadata import version; print(version('biodigest'))\""), emit: versions_biodigest, topic: versions

    script:
    """
    python - <<'EOF'
    from biodigest import setup
    from biodigest.evaluation.mappers.mapper import FileMapper

    # download into a local directory instead of the package directory
    setup.main(setup_type="api", path="mapping_files")
    # the download does not report failures, so check that all required files exist
    FileMapper(files_dir="mapping_files").check_for_setup_sources()
    EOF
    """
}
