process ECHO_SAMPLE {
    tag {sample_id}

    input:
    tuple val (sample_id), val (message)

    output:
    stdout emit: out

    script:
    """
    echo "Sample: ${sample_id} -- ${message}"
    """
}

workflow {
    ECHO_SAMPLE(pipeline_input_ch)
}