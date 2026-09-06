process RENAME_CONTIGS {
    tag { "rename_header_${barcode}_${sample}" }

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '10h'

    publishDir "${params.outdir}/fin", mode: 'copy', overwrite: true
    
    input:
    tuple val(sample), val(barcode), path(polished2_fasta)

    output:
    tuple val(sample), val(barcode), path("${barcode}_${sample}_final.fasta"), emit: renamed_fasta

    script:
    def medaka_model = 'r1041_e82_400bps_sup_v4.3.0'
    """
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate influB
    echo "Renaming contigs for ${barcode}_${sample}..."

    awk -v bc="${barcode}" -v smp="${sample}" '
        /^>/ {
            i++; 
            print ">" bc "_" smp "_" i
            next
        } 
        { print }
    ' ${polished2_fasta} > ${barcode}_${sample}_final.fasta
    
    echo "Validating renamed FASTA..."
    if [ ! -s "./${barcode}_${sample}_final.fasta" ]; then
        echo "ERROR: Renaming failed! Output FASTA is missing or empty." >&2
        exit 1
    else
        echo "SUCCESS: Contigs renamed successfully. New headers:"
        grep '^>' "./${barcode}_${sample}_final.fasta"
    fi

    """
}
