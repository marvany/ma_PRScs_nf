process JOIN_MODELS {
    
    tag "Join chromosome-specific PRScs models"
    publishDir "${params.outdir}/logs", mode: 'copy', pattern: "*.{out,err}"
    
    input:
    val models_complete
    
    output:
    val true, emit: complete
    path "PRScs_join_models.out", emit: log_out
    path "PRScs_join_models.err", emit: log_err
    
    script:
    """
    #!/bin/bash
    
    # Change to the R directory
    cd ${params.scripts_dir}
    
    # Execute the R script for joining models
    Rscript --verbose ${params.scripts_dir}/PRScs_3.join_bed-based_PRScs_models_CMC_EUR.PGC.R \\
        -r ${params.recipe} \\
        -f ${params.cluster_file} \\
        -c ${params.cluster} \\
        -a ${params.cohort_file} \\
        -b ${params.cohort} \\
        -s ${params.superpopulation} > PRScs_join_models.out 2> PRScs_join_models.err
    
    # Check if the script executed successfully
    if [ \$? -eq 0 ]; then
        echo "PRScs model joining completed successfully" >> PRScs_join_models.out
    else
        echo "PRScs model joining failed" >> PRScs_join_models.err
        exit 1
    fi
    """
    
    stub:
    """
    touch PRScs_join_models.out
    touch PRScs_join_models.err
    echo "true"
    """
}
