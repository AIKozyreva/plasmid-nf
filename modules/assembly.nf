process ASSEMBLY {
    errorStrategy 'ignore'
    tag { "${params.assembler}_${barcode}_${sample}" }

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '10h'

    publishDir "${params.outdir}/assembly_runs/${barcode}_${sample}", mode: 'copy', overwrite: true
    publishDir "${params.outdir}/all_assemblies", mode: 'copy', overwrite: true, saveAs: { filename -> filename.endsWith('_draft.fasta') ? filename : null }
    
    input:
    tuple val(sample), val(barcode), path(filtered_fastq), val(ref_fasta), val(ref_len)

    output:
    path("assembly_output/*"), emit: full_run_dir
    path("${barcode}_${sample}_draft.fasta"), emit: draft_fasta
    tuple val(sample), val(barcode), emit: failed_samples

    script:
    def assembler = params.assembler ?: 'flye'
    def success=0 
    """
    source ~/miniconda3/etc/profile.d/conda.sh
    mkdir -p assembly_output
    success=0

    if [ "${assembler}" = "autocycler" ]; then
        echo "Starting Autocycler assembly for ${barcode}_${sample}..."
        conda activate autocycler
        export PATH="${params.autocycler_path}:\$PATH"

        autocycler_size=${ref_len}
        if [ -z "\${autocycler_size}" ] || [ "\${autocycler_size}" -eq 0 ]; then
            echo "Reference length is 0 or not provided. Using default size: 10000"
            autocycler_size=10000
        fi

        if autoautocycler.sh --size \${autocycler_size} -o ./assembly_output -t 2 -j 2 -a "flye metamdbg miniasm necat raven redbean" ${filtered_fastq}; then
            find ./assembly_output -name "consensus_assembly.fasta" -exec cp {} ./${barcode}_${sample}_draft.fasta \\;
            success=1

            if [ ! -s "./${barcode}_${sample}_draft.fasta" ]; then
                echo "WARNING: Autocycler finished, but consensus is empty! Starting Flye fallback..."
                rm -rf ./assembly_output
                mkdir -p assembly_output
                conda activate WGA_assembly
                if flye --nano-raw ${filtered_fastq} -o ./assembly_output --threads ${params.threads} --meta; then
                    find ./assembly_output -name "assembly.fasta" -exec cp {} ./${barcode}_${sample}_draft.fasta \\;
                    success=1
                else
                    success=0
                fi
            fi
            
        else
            echo "WARNING: Autocycler failed for ${barcode}_${sample}! Starting Flye..."
            
            rm -rf ./assembly_output
            mkdir -p assembly_output
            
            conda activate WGA_assembly
            if flye --nano-raw ${filtered_fastq} -o ./assembly_output --threads ${params.threads} --meta; then
                find ./assembly_output -name "assembly.fasta" -exec cp {} ./${barcode}_${sample}_draft.fasta \\;
                success=1
            fi
        fi
    else 
        echo "Starting Flye assembly for ${sample}..."
        conda activate WGA_assembly
        if flye --nano-raw ${filtered_fastq} -o ./assembly_output --threads ${params.threads} --meta; then
            find ./assembly_output -name "assembly.fasta" -exec cp {} ./${barcode}_${sample}_draft.fasta \\;
            success=1
        fi
    fi

    echo "Validating assembly output..."
    if [ "${success}" -ne 1 ] || [ ! -s "./${barcode}_${sample}_draft.fasta" ]; then
        echo "ERROR: Assembly failed! Final FASTA file ./${barcode}_${sample}_draft.fasta is missing or empty." >&2
    else
        echo "SUCCESS: Assembly completed. File size: \$(du -sh ./${barcode}_${sample}_draft.fasta | cut -f1)"
    fi
    """
}