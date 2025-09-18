process GENERATE_MODELS {
    
    tag "Generate PRScs models"
    publishDir "${params.outdir}/logs", mode: 'copy', pattern: "*.{out,err}"
    
    input:
    val ready_complete
    
    output:
    val true, emit: complete
    path "PRScs_create_models.out", emit: log_out  
    path "PRScs_create_models.err", emit: log_err
    
    script:
    """
    #!/bin/bash
    
    # Change to the R directory
    cd ${params.scripts_dir}
    
    # Execute the R script for model generation
    Rscript --verbose ${params.scripts_dir}/PRScs_2.generate_PRScs_models_phigrid_and_auto_CMC_EUR.PGC.R \\
        -r ${params.recipe} \\
        -f ${params.cluster_file} \\
        -c ${params.cluster} \\
        -a ${params.cohort_file} \\
        -b ${params.cohort} \\
        -s ${params.superpopulation} > PRScs_create_models.out 2> PRScs_create_models.err
    
    # Check if the script executed successfully
    if [ \$? -eq 0 ]; then
        echo "PRScs model generation completed successfully" >> PRScs_create_models.out
    else
        echo "PRScs model generation failed" >> PRScs_create_models.err
        exit 1
    fi
    """
    
    stub:
    """
    touch PRScs_create_models.out
    touch PRScs_create_models.err
    echo "true"
    """
}
