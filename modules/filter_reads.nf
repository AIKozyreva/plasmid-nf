process FILTER_READS {
    tag { "Filter_${barcode}_${sample}" }

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '5h'

    publishDir "${params.outdir}/filtering", mode: 'copy', overwrite: true

    input:
    tuple val(sample), val(barcode), path(merged_reads_fastq), val(ref_fasta)

    output:
    tuple val(sample), val(barcode), path("*_FILTERED.fastq.gz"), val(ref_fasta), env(ref_len), emit: filtered
    tuple val(sample), val(barcode), path("failed/*_FAILED.fastq.gz"), val(ref_fasta), emit: failed_reads

    script:
    """
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate fastqc_env
    qf=12
    ref_len=0
    flen_min=500
    flen_max_arg=""
    if [ "${ref_fasta}" != "null" ] && [ -s "${ref_fasta}" ]; then
        ref_len=\$(grep -v '^>' "${ref_fasta}" | tr -d '\n' | wc -c)
        flen_max=\$((ref_len + 500))
        echo "BARCODE=${barcode} REF=${ref_fasta} REF_LEN=\${ref_len} FLEN_MAX=\${flen_max}"
        flen_max_arg="--length_limit \${flen_max}"
    fi

    fastplong -i ${merged_reads_fastq} -o ${barcode}_FILTERED.fastq -q \${qf} --length_required \${flen_min} \${flen_max_arg} --thread ${task.cpus} --failed_out ${barcode}_FAILED.fastq --report_title '${barcode}_filter_report'

    mkdir -p failed
    mv ${barcode}_FAILED.fastq failed/

    gzip -f ${barcode}_FILTERED.fastq
    gzip -f failed/${barcode}_FAILED.fastq
    """
}