process COMP_W_REF {
    tag { "Ref_comparison_${barcode}_${sample}" }

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '4h'

    publishDir "${params.outdir}/comp_align", mode: 'copy', overwrite: true, saveAs: { filename -> filename.endsWith('.txt') ? filename : null }
    
    input:
    tuple val(sample), val(barcode), path(final_fasta), val(ref_fasta)

    output:
    path("*.txt"), optional: true, emit: alignment_report
    path("sample_summary.line"), emit: summary_line

    script:
    """
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate WGA_assembly
    
    echo -e "barcode\tsample\tref_fasta_filename\tstatus" > sample_summary.line

    if [ "${ref_fasta}" != "null" ]; then
        ref_filename=\$(basename "${ref_fasta}")
    else
        ref_filename="no_ref"
    fi

    OUTPUT_TXT="${barcode}_${sample}-\${ref_filename}.txt"

    if [ "${ref_fasta}" != "null" ] && [ -s "${ref_fasta}" ]; then
        echo "Comparison ${barcode}_${sample} with ref \${ref_filename}..."

        set +e
        /home/kozyreva_ai/compare_assemblies.py --aligner edlib ${final_fasta} ${ref_fasta} > "\${OUTPUT_TXT}" 2> script_error.log
        EXIT_CODE=\$?
        set -e

        if [ -f "\${OUTPUT_TXT}" ]; then
            words=\$(wc -w < "\${OUTPUT_TXT}")
        else
            words=0
        fi

        if [ "\$words" -gt 0 ]; then
            echo "SUCCESS: Comparison passed for ${barcode}_${sample}."
            echo -e "${barcode}\t${sample}\t\${ref_filename}\tPassed" >> sample_summary.line
        else
            echo "WARNING: ${barcode}_${sample} is too dissimilar from reference or script failed!"
            echo -e "${barcode}\t${sample}\t\${ref_filename}\tFailed" >> sample_summary.line
            
            rm -f "\${OUTPUT_TXT}"
        fi

    else
        echo "No reference for ${barcode}_${sample}. Skipping alignment."
        echo "No reference for this sample." > "\${OUTPUT_TXT}"
        echo -e "${barcode}\t${sample}\tno_ref\tNo_Reference" >> sample_summary.line
        rm -f "\${OUTPUT_TXT}"
    fi

    find . -maxdepth 1 -name "*.txt" -size 0 -delete    

    for f in *.txt; do
        if [ -f "\$f" ]; then
            words=\$(wc -w < "\$f")
            if [ "\$words" -eq 0 ]; then
                echo "Removing empty or white-space-only file: \$f"
                rm -f "\$f"
            fi
        fi
    done

    """
}
