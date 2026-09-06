process IGV_MAPPING {
    tag { "IGVdata_for_${barcode}_${sample}_(back_mapping)" }

    cpus { params.threads }
    memory { "${params.mem} GB" }
    time '4h'
 TBD
}
