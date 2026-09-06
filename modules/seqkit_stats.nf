process SEQKIT_STATS {
    tag {"global_seqkit_stats"}

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '5h'

    publishDir "${params.outdir}/QC_reads", mode: 'copy', overwrite: true

    input:
    tuple val(stage), path(merged_reads_fastq)

    output:
    path ('*_seqkit_stats.tsv'), emit: out

    script:
    """
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate influB
    seqkit stats ${merged_reads_fastq} -T -a > ${stage}_seqkit_stats.tsv
    """
}