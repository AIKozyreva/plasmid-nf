nextflow.enable.dsl = 2

params.worklist     = params.containsKey('worklist') ? params.worklist : 'worklist.tsv'
params.rawdata_path = params.containsKey('rawdata_path') ? params.rawdata_path : ''
params.threads      = params.containsKey('threads') ? params.threads : 40
params.mem          = params.containsKey('mem') ? params.mem : 32
params.outdir       = params.containsKey('outdir') ? params.outdir : 'results_def/'
params.assembler    = params.containsKey('assembler') ? params.assembler : 'flye'
params.autocycler_path = params.containsKey('autocycler_path') ? params.autocycler_path : '/home/kozyreva_ai/Autocycler/scripts'

include { MERGE_READS } from './modules/merge_reads.nf'
include { READS_QC } from './modules/reads_qc.nf'
include { SEQKIT_STATS } from './modules/seqkit_stats.nf'
include { MULTIQC } from './modules/multiQC.nf'
include { FILTER_READS } from './modules/filter_reads.nf'
include { SEQKIT_STATS as SEQKIT_STATS_POST } from './modules/seqkit_stats.nf'
include { ASSEMBLY } from './modules/assembly.nf'
include { SEQKIT_STATS as SEQKIT_STATS_DRAFTS } from './modules/seqkit_stats.nf'
include { POLISHING as POLISHING_R1 } from './modules/polishing.nf'
include { REORIENT } from './modules/reorient.nf'
include { POLISHING as POLISHING_R2 } from './modules/polishing.nf'
include { RENAME_CONTIGS } from './modules/rename_contigs.nf'
include { ANNOTATION } from './modules/annotation.nf'
include { COMP_W_REF } from './modules/comp_w_ref.nf'
include { IGV_MAPPING } from './modules/igv_mapping.nf'

workflow {
    
    Channel
        .fromPath(params.worklist)
        .splitCsv(header: true, sep: ',')
        //.view { row -> "ROW: ${row}" }
        .map { row ->
            def raw_path = row.rawdata_path && row.rawdata_path.trim()
                           ? row.rawdata_path
                           : params.rawdata_path

            if( !raw_path ) {
                throw new IllegalArgumentException(
                    "No rawdata_path for sample ${row.sample} " +
                    "and no global params.rawdata_path provided"
                )
            }
            def ref = row.ref_path && row.ref_path.trim()
                      ? file(row.ref_path)
                      : null

            def clean_sample = row.sample.replaceAll(/_/, '-')
            clean_sample = clean_sample.replaceAll(/[\+\/\\\.,]/, '')
            clean_sample = clean_sample.replaceAll(/-+/, '-')

            [
                clean_sample,
                row.barcode,
                file("${raw_path}/${row.barcode}"),
                //row.raw_path,
                ref
            ]
        }
        .set { pipeline_input_ch }
    //pipeline_input_ch.view()
    
    MERGE_READS(pipeline_input_ch)
    //MERGE_READS.out.merged.view()

    READS_QC(MERGE_READS.out.merged)

    MERGE_READS.out.merged
        .map { sample, barcode, merged_reads_fastq, ref_fasta -> merged_reads_fastq }
        .filter { it -> it && it.exists() && it.size() > 0 }
        .collect()
        .map { files -> tuple('pre_filter', files) }
        .set { raw_merged_fastqs_for_stats }

    //raw_merged_fastqs_for_stats.view()
    SEQKIT_STATS(raw_merged_fastqs_for_stats)
    
    //READS_QC.out.nanoplot_reports.view()

    READS_QC.out.nanoplot_reports
    .filter { it -> it && it.exists() }
    .collect()
    .map { dirs -> tuple('pre_filter-Nanoplot', dirs) }
    .set { nanoplot_inputs_for_multiqc }
    //nanoplot_inputs_for_multiqc.view()
    
    MULTIQC(nanoplot_inputs_for_multiqc)
    FILTER_READS(MERGE_READS.out.merged)
    FILTER_READS.out.filtered.view { s, bc, fq, ref, len -> "S=${s} BC=${bc} LEN=${len}" }

    FILTER_READS.out.filtered
        .map { sample, barcode, filtered_fastq, ref_fasta, ref_len -> filtered_fastq }
        .filter { it -> it && it.exists() && it.size() > 0 }
        .collect()
        .map { files -> tuple('post_filter', files) }
        .set { filtered_fastq_for_seqkit }

    SEQKIT_STATS_POST(filtered_fastq_for_seqkit)

    ASSEMBLY(FILTER_READS.out.filtered)

    ASSEMBLY.out.draft_fasta
        .filter { it -> it && it.exists() && it.size() > 0 }
        .collect()
        .map { files -> tuple('draft_assemblies', files) }
        .set { ch_drafts_fasta_for_seqkit_stats }

    SEQKIT_STATS_DRAFTS(ch_drafts_fasta_for_seqkit_stats)

    FILTER_READS.out.filtered
        .map { sample, barcode, filtered_fastq, ref_fasta, ref_len -> [ tuple(sample, barcode), filtered_fastq ] }
        .set { ch_filtered_reads_for_join }
    
    ASSEMBLY.out.failed_samples
        .collect()
        .view { failed_list -> "=======FAILED ASSEMBLIES: ${failed_list}=========" }
    
    ASSEMBLY.out.draft_fasta
        .map { draft_file -> 
            def parts = draft_file.name.tokenize('_')
            def barcode = parts[0]
            def sample = parts[1]
            //def matcher = (draft_file.name =~ /^(barcode\d+)_(.+)_draft\.fasta\$/)
            //def barcode = matcher[0][1]
            //def sample = matcher[0][2]
            [ tuple(sample, barcode), draft_file ]
        }
        .set { ch_drafts_for_join }

    ch_filtered_reads_for_join
        .join(ch_drafts_for_join) // На выходе: [ [sample, barcode], path(fastq), path(draft_fasta) ]
        .filter { key, fastq, draft -> draft && draft.exists() && draft.size() > 0 }
        .map { key, fastq, draft -> [ "1", key[0], key[1], fastq, draft ] } // Разворачиваем обратно в плоский tuple
        .set { ch_polishing_input }

    POLISHING_R1(ch_polishing_input)

    // создать каналы для объединения по составному ключу [sample, barcode]
    ch_polished1_keyed = POLISHING_R1.out.polished_fasta.map { sample, barcode, fasta -> [ tuple(sample, barcode), fasta ] }
    ch_refs_keyed      = FILTER_READS.out.filtered.map { sample, barcode, fq, ref, len -> [ tuple(sample, barcode), ref ] }

    ch_polished1_keyed
        .join(ch_refs_keyed) // На выходе: [ [sample, barcode], polished_fasta, ref_fasta ]
        .branch { it ->
            def sample    = it[0][0]
            def barcode   = it[0][1]
            def polished  = it[1]
            def ref_fasta = it[2]

            with_ref: ref_fasta && ref_fasta.toString() != 'null' && file(ref_fasta).exists()
                return [ sample, barcode, polished, ref_fasta ]
            without_ref: true
                return [ sample, barcode, polished ]
        }
        .set { ch_polishing1_branches }

    // СЦЕНАРИЙ ДЛЯ ОБРАЗЦОВ С РЕФЕРЕНСАМИ (идут на переориентацию и 2-й раунд полировки)
    REORIENT(ch_polishing1_branches.with_ref)

    ch_reoriented_keyed = REORIENT.out.restarted_fasta.map { sample, barcode, restarted -> [ tuple(sample, barcode), restarted ] }
    ch_filtered_fq_keyed = FILTER_READS.out.filtered.map { sample, barcode, fq, ref, len -> [ tuple(sample, barcode), fq ] }

    ch_reoriented_keyed
        .join(ch_filtered_fq_keyed) // На выходе: [ [sample, barcode], restarted_fasta, fq ]
        .map { key, restarted, fq -> [ "2", key[0], key[1], fq, restarted ] }
        .set { ch_polishing2_input }

    POLISHING_R2(ch_polishing2_input)

    // СЦЕНАРИЙ СЛИЯНИЯ ПОТОКОВ ДЛЯ ДАЛЬНЕЙШЕГО РЕНЕЙМИНГА (ветка с референсами после 2ого рауннда полишинга + ветка без референсов после 1ого раунда полировки)
    ch_from_round2 = POLISHING_R2.out.polished_fasta

    ch_from_round1_only = ch_polishing1_branches.without_ref

    ch_final_for_rename = ch_from_round2.mix(ch_from_round1_only)

    RENAME_CONTIGS(ch_final_for_rename)
    ANNOTATION(RENAME_CONTIGS.out.renamed_fasta)

    FILTER_READS.out.filtered
        .map { sample, barcode, filtered_fastq, ref_fasta, ref_len -> [ tuple(sample, barcode), ref_fasta ] }
        .set { ch_refs_for_compare }

    RENAME_CONTIGS.out.renamed_fasta
        .map { sample, barcode, final_fasta -> [ tuple(sample, barcode), final_fasta ] }
        .set { ch_final_fasta_for_compare }

    ch_final_fasta_for_compare
        .join(ch_refs_for_compare) // [ [sample, barcode], final_fasta, ref_fasta ]
        .map { key, final_fasta, ref_fasta -> [ key[0], key[1], final_fasta, ref_fasta ] }
        .set { ch_compare_input }

    COMP_W_REF(ch_compare_input)
    COMP_W_REF.out.summary_line
        .collectFile(
            name: 'comp_align_summary.tsv', 
            storeDir: "${params.outdir}/comp_align", 
            keepHeader: true, 
            sort: true
        )

}
