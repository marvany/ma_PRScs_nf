#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
========================================================================================
    PRScs Nextflow Pipeline
    Automated PRScs workflow for polygenic risk score calculation
    Based on Georgios Voloudakis R scripts
========================================================================================

========================================================================================
    PROCESSES
========================================================================================
*/

process READY_GWAS {
    tag "Format GWAS summary statistics"
    publishDir "${params.outdir}/logs", mode: 'copy', pattern: "*.{out,err}"
    
    output:
    val true, emit: complete
    path "PRSsumstats.out", emit: log_out, optional: true
    path "PRSsumstats.err", emit: log_err, optional: true
    
    script:
    """
    #!/bin/bash
    set -euo pipefail
    
    # Change to the R directory
    #cd ${params.scripts_dir}
    
    echo "Starting GWAS formatting at: \$(date)"
    echo "Working directory: \$(pwd)"
    
    # Execute the R script for GWAS formatting
    Rscript --verbose ${params.scripts_dir}/PRScs_1.ready_GWAS_CMC.R \\
    - 
    > PRSsumstats.out 2> PRSsumstats.err
    
    echo "GWAS formatting completed at: \$(date)"
    """
}

process GENERATE_MODELS {
    tag "Generate PRScs models"
    publishDir "${params.outdir}/logs", mode: 'copy', pattern: "*.{out,err}"
    
    input:
    val ready_complete
    
    output:
    val true, emit: complete
    path "PRScs_create_models.out", emit: log_out, optional: true
    path "PRScs_create_models.err", emit: log_err, optional: true
    
    script:
    """
    #!/bin/bash
    set -euo pipefail
    
    # Change to the R directory
    cd ${params.scripts_dir}
    
    echo "Starting PRScs model generation at: \$(date)"
    echo "Working directory: \$(pwd)"
    
    # Execute the R script for model generation
    Rscript --verbose ${params.scripts_dir}/PRScs_2.generate_PRScs_models_phigrid_and_auto_CMC_EUR.PGC.R \\
        -r ${params.recipe} \\
        -f ${params.cluster_file} \\
        -c ${params.cluster} \\
        -a ${params.cohort_file} \\
        -b ${params.cohort} \\
        -s ${params.superpopulation} > PRScs_create_models.out 2> PRScs_create_models.err
    
    echo "PRScs model generation completed at: \$(date)"
    """
}

process JOIN_MODELS {
    tag "Join chromosome-specific PRScs models"
    publishDir "${params.outdir}/logs", mode: 'copy', pattern: "*.{out,err}"
    
    input:
    val models_complete
    
    output:
    val true, emit: complete
    path "PRScs_join_models.out", emit: log_out, optional: true
    path "PRScs_join_models.err", emit: log_err, optional: true
    
    script:
    """
    #!/bin/bash
    set -euo pipefail
    
    # Change to the R directory
    cd ${params.scripts_dir}
    
    echo "Starting PRScs model joining at: \$(date)"
    echo "Working directory: \$(pwd)"
    
    # Execute the R script for joining models
    Rscript --verbose ${params.scripts_dir}/PRScs_3.join_bed-based_PRScs_models_CMC_EUR.PGC.R \\
        -r ${params.recipe} \\
        -f ${params.cluster_file} \\
        -c ${params.cluster} \\
        -a ${params.cohort_file} \\
        -b ${params.cohort} \\
        -s ${params.superpopulation} > PRScs_join_models.out 2> PRScs_join_models.err
    
    echo "PRScs model joining completed at: \$(date)"
    """
}

process SCORE_INDIVIDUALS {
    tag "Score individuals using PRScs models"
    publishDir "${params.outdir}/logs", mode: 'copy', pattern: "*.{out,err}"
    
    input:
    val join_complete
    
    output:
    val true, emit: complete
    path "PRScs_cal_scores.out", emit: log_out, optional: true
    path "PRScs_cal_scores.err", emit: log_err, optional: true
    
    script:
    """
    #!/bin/bash
    set -euo pipefail
    
    # Change to the R directory
    cd ${params.scripts_dir}
    
    echo "Starting PRScs individual scoring at: \$(date)"
    echo "Working directory: \$(pwd)"
    
    # Execute the R script for scoring individuals
    Rscript --verbose ${params.scripts_dir}/PRScs_4.score_bed-based_individuals_CMC_EUR.PGC.R \\
        -r ${params.recipe} \\
        -f ${params.cluster_file} \\
        -c ${params.cluster} \\
        -a ${params.cohort_file} \\
        -b ${params.cohort} \\
        -s ${params.superpopulation} > PRScs_cal_scores.out 2> PRScs_cal_scores.err
    
    echo "PRScs individual scoring completed at: \$(date)"
    """
}

/*
========================================================================================
    MAIN WORKFLOW
========================================================================================
*/

workflow {
    
    log.info """
    ========================================================================================
                              PRScs Nextflow Pipeline v3
    ========================================================================================
    Recipe file         : ${params.recipe}
    Cluster file        : ${params.cluster_file}
    Cohort file         : ${params.cohort_file}
    Cluster             : ${params.cluster}
    Cohort              : ${params.cohort}
    Superpopulation     : ${params.superpopulation}
    Output directory    : ${params.outdir}
    Scripts directory   : ${params.scripts_dir}
    ========================================================================================
    """

    // Sequential workflow matching your original commands:
    // 1. R1: Format GWAS summary statistics
    READY_GWAS()
    
    // 2. R2: Generate PRScs models (depends on R1)
    GENERATE_MODELS(READY_GWAS.out.complete)
    
    // 3. R3: Join chromosome-specific models (depends on R2)
    JOIN_MODELS(GENERATE_MODELS.out.complete)
    
    // 4. R4: Score individuals using the models (depends on R3)
    SCORE_INDIVIDUALS(JOIN_MODELS.out.complete)
    
}

/*
========================================================================================
    WORKFLOW COMPLETION
========================================================================================
*/

workflow.onComplete {
    log.info """
    ========================================================================================
                                    Workflow Summary
    ========================================================================================
    Completed at: ${workflow.complete}
    Duration    : ${workflow.duration}
    Success     : ${workflow.success}
    Exit status : ${workflow.exitStatus}
    Error report: ${workflow.errorReport ?: 'No errors'}
    ========================================================================================
    
    Results can be found in: ${params.outdir}
    
    Pipeline Steps Completed:
    1. ✓ GWAS formatting (PRScs_1.ready_GWAS_CMC.R)
    2. ✓ Model generation (PRScs_2.generate_PRScs_models_phigrid_and_auto_CMC_EUR.PGC.R)
    3. ✓ Model joining (PRScs_3.join_bed-based_PRScs_models_CMC_EUR.PGC.R)
    4. ✓ Individual scoring (PRScs_4.score_bed-based_individuals_CMC_EUR.PGC.R)
    ========================================================================================
    """
}
