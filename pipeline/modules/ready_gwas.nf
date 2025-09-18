process READY_GWAS {
    
    tag "Format GWAS summary statistics"
    publishDir "${params.outdir}/logs", mode: 'copy', pattern: "*.{out,err}"
    
    output:
    val true, emit: complete
    path "PRSsumstats.out", emit: log_out
    path "PRSsumstats.err", emit: log_err
    
    script:
    """
    #!/bin/bash
    
    # Change to the R directory
    cd ${params.scripts_dir}
    
    # Execute the R script for GWAS formatting
    Rscript --verbose ${params.scripts_dir}/PRScs_1.ready_GWAS_CMC.R > PRSsumstats.out 2> PRSsumstats.err
    
    # Check if the script executed successfully
    if [ \$? -eq 0 ]; then
        echo "GWAS formatting completed successfully" >> PRSsumstats.out
    else
        echo "GWAS formatting failed" >> PRSsumstats.err
        exit 1
    fi
    """
    
    stub:
    """
    touch PRSsumstats.out
    touch PRSsumstats.err
    echo "true"
    """
}
