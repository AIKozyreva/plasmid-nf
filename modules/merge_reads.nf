process MERGE_READS {
    tag { "${barcode}_${sample}" }

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '5h'

    publishDir "${params.outdir}/raw_merged", mode: 'copy', overwrite: true

    input:
    tuple val(sample), val(barcode), val(raw_reads), val(ref_fasta)
    //tuple val(sample), val(barcode), path(raw_reads), val(ref_fasta)

    output:
    tuple val(sample), val(barcode), path('*.merged.fastq.gz'), val(ref_fasta), emit: merged

    script:
    """
    seqkit scat -f ${raw_reads} | gzip > ${barcode}_${sample}.merged.fastq.gz
    sync
    sleep 3
    """
}