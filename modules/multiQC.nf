process MULTIQC {
    tag { "multiqc_${stage}" }

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '5h'

    publishDir "${params.outdir}/QC_reads/raw", mode: 'copy', overwrite: true

    input:
    tuple val(stage), path(nanoplot_raw_dir)

    output:
    path('*.html'), emit: multiqc_html
    //path "*_multiqc_data"        emit: multiqc_data

    script:
    """
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate multiqc_env
    multiqc ${nanoplot_raw_dir.join(' ')} -o . -n "${stage}_multiQC"
    """
}