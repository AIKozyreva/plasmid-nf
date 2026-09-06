process ANNOTATION {
    errorStrategy 'ignore'
    tag { "annotation_${barcode}_${sample}" }

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '4h'

    publishDir "${params.outdir}/", mode: 'copy', overwrite: true
    
    input:
    tuple val(sample), val(barcode), path(final_fasta)

    output:
    path("annot/*"), emit: annotation_files

    script:
    """
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate plannotate
    export PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION=python

    echo "Starting plannotate for ${barcode}_${sample}..."
    mkdir -p annot

    plannotate batch -i ${final_fasta} -o ./annot -hf -d -c -f ${barcode}_${sample}
    
    echo "Validating annotation output..."
    if [ ! -d "./annot" ] || [ \$(find ./annot -type f | wc -l) -eq 0 ]; then
        echo "ERROR: plannotate failed! Output directory is empty or missing." >&2
        exit 1
    else
        echo "SUCCESS: Annotation completed. Generated files:"
        ls -lh ./annot
    fi

    """
}