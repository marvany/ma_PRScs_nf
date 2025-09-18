process SCORE_INDIVIDUALS {
    
    tag "Score individuals using PRScs models"
    publishDir "${params.outdir}/logs", mode: 'copy', pattern: "*.{out,err}"
    
    input:
    val join_complete
    
    output:
    val true, emit: complete
    path "PRScs_cal_scores.out", emit: log_out
    path "PRScs_cal_scores.err", emit: log_err
    
    script:
    """
    #!/bin/bash
    
    # Change to the R directory
    cd ${params.scripts_dir}
    
    # Execute the R script for scoring individuals
    Rscript --verbose ${params.scripts_dir}/PRScs_4.score_bed-based_individuals_CMC_EUR.PGC.R \\
        -r ${params.recipe} \\
        -f ${params.cluster_file} \\
        -c ${params.cluster} \\
        -a ${params.cohort_file} \\
        -b ${params.cohort} \\
        -s ${params.superpopulation} > PRScs_cal_scores.out 2> PRScs_cal_scores.err
    
    # Check if the script executed successfully
    if [ \$? -eq 0 ]; then
        echo "PRScs individual scoring completed successfully" >> PRScs_cal_scores.out
    else
        echo "PRScs individual scoring failed" >> PRScs_cal_scores.err
        exit 1
    fi
    """
    
    stub:
    """
    touch PRScs_cal_scores.out
    touch PRScs_cal_scores.err
    echo "true"
    """
}
