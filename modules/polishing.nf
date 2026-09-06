process POLISHING {
    tag { "polishing${stage}_${barcode}_${sample}" }

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '10h'

    publishDir "${params.outdir}/polishing/round${stage}", mode: 'copy', overwrite: true
    
    input:
    tuple val(stage), val(sample), val(barcode), path(filtered_fastq), path(draft_fasta)

    output:
    tuple val(sample), val(barcode), path("${barcode}_${sample}_polished${stage}.fasta"), emit: polished_fasta

    script:
    def medaka_model = 'r1041_e82_400bps_sup_v4.3.0'
    """
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate WGA_assembly
    echo "Running Medaka consensus Round ${stage} for ${barcode}_${sample}..."
    medaka_consensus -i ${filtered_fastq} -d ${draft_fasta} -o ./medaka_output -t ${task.cpus} -m ${medaka_model}
    
    if [ -f ./medaka_output/consensus.fasta ]; then
        cp ./medaka_output/consensus.fasta ./${barcode}_${sample}_polished${stage}.fasta
    fi

    echo "Validating Polishing Round ${stage} output..."
    if [ ! -s "./${barcode}_${sample}_polished${stage}.fasta" ]; then
        echo "ERROR: Medaka polishing Round ${stage} failed! Output file is missing or empty." >&2
        exit 1
    else
        echo "SUCCESS: Round ${stage} polishing completed. File: ./${barcode}_${sample}_polished${stage}.fasta"
    fi

    """
}