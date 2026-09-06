process REORIENT {
    tag "reorient_${barcode}_${sample}"

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '4h'

    publishDir "${params.outdir}/polishing/restart", mode: 'copy', overwrite: true
    
    input:
    tuple val(sample), val(barcode), path(polished_fasta), path(ref_fasta)

    output:
    tuple val(sample), val(barcode), path("${barcode}_${sample}_restarted.fasta"), emit: restarted_fasta

    script:
    def medaka_model = 'r1041_e82_400bps_sup_v4.3.0'
    """
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate WGA_assembly
    REORIENTED=false

    if [ "${ref_fasta}" != "null" ] && [ -s "${ref_fasta}" ]; then
        echo "Extracting first 60bp from reference for ${barcode}_${sample}..."
        
        seqkit head -n 1 ${ref_fasta} | seqkit subseq -r 1:60 > start_60bp.fasta
        
        echo "Running seqkit locate..."
        seqkit locate -m 10 -c -i -f start_60bp.fasta ${polished_fasta} > locate.tsv

        if [ \$(wc -l < locate.tsv) -gt 1 ]; then
            echo "Reference start sequence found. Running Python reorientation script..."

            python3 << 'EOF'
import pandas as pd
import subprocess

df = pd.read_csv("locate.tsv", sep="\t")
in_pwd = "${polished_fasta}"
out_pwd = "${barcode}_${sample}_restarted.fasta"

strand = df.iloc[0]['strand']
if strand == "-":
    start = int(df.iloc[0]['end']) + 1
    cmd = f"seqkit restart -i {start} {in_pwd} | seqkit seq -p -r > {out_pwd}"
    subprocess.run(cmd, shell=True, check=True)
else:
    start = int(df.iloc[0]['start'])
    cmd = f"seqkit restart -i {start} {in_pwd} > {out_pwd}"
    subprocess.run(cmd, shell=True, check=True)
EOF
            REORIENTED=true
        else
            echo "WARN: Ref start wasn't found in the ${barcode}_${sample}_polished1"
        fi
    fi

    if [ "\$REORIENTED" = false ]; then
        if [ "${ref_fasta}" = "null" ]; then
            echo "No reference provided for ${barcode}_${sample}. Starting dnaapler..."
        else
            echo "Falling back to dnaapler all for ${barcode}_${sample} due to missing anchor site..."
        fi
        
        if dnaapler all -i ${polished_fasta} -o ./dnaapler_rotated -p BC${barcode} -t ${params.threads} -f; then
            echo "dnaapler finished successfully. Extracting rotated fasta..."
            
            find ./dnaapler_rotated -name "*_reoriented.fasta" -exec cp {} ./${barcode}_${sample}_restarted.fasta \\;
            
            if [ -s "./${barcode}_${sample}_restarted.fasta" ]; then
                REORIENTED=true
            else
                REORIENTED=false
            fi
        else
            echo "WARN: dnaapler execution failed for ${barcode}_${sample}!"
        fi
    fi

    if [ "\$REORIENTED" = false ]; then
        echo "WARN: ref-start mapping and dnaapler failed for ${barcode}_${sample}. Saving original polished1 fasta without changes."
        cp ${polished_fasta} ./${barcode}_${sample}_restarted.fasta
    fi

    """
}
