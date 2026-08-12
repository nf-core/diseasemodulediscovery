
process PREFIXLINES {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "modulediscovery_python_dependencies:894e0b47d51d9d4b" // automatically generated

    input:
    tuple val(meta), path(file)
    val prefix


    output:
    tuple val(meta), path("${file.baseName}.prefixed.${file.extension}")

    when:
    task.ext.when == null || task.ext.when


    script:
    """
    sed -e 's/^/${prefix}/' $file > ${file.baseName}.prefixed.${file.extension}
    """
}
