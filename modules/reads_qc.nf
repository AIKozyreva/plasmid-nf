process READS_QC {
    tag { "${barcode}_${sample}" }

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '5h'

    publishDir "${params.outdir}/QC_reads/raw", mode: 'copy', overwrite: true

    input:
    tuple val(sample), val(barcode), path(reads_fastq), val(ref_fasta)

    output:
    //tuple val(sample), val(barcode), path(reads_fastq), val(ref_fasta), emit: passthrough
    path "*_nanoplot", emit: nanoplot_reports

    script:
    """
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate pycoQC
    mkdir -p nanoplot
    NanoPlot --threads ${task.cpus} --only-report --info_in_report --fastq ${reads_fastq} --outdir ${barcode}_${sample}_nanoplot --prefix ${barcode}_${sample}_
    """
}