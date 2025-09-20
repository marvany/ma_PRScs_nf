#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

/*
========================================================================================
    PRScs Nextflow Pipeline
    Automated PRScs workflow for polygenic risk score calculation
    Based on Georgios Voloudakis R scripts
========================================================================================
*/

import utils.Recipe
import java.nio.file.Paths

// We source recipe parameters
def recipe = Recipe.load(file(params.recipe))      // nextflow automatically assigns CLI arguments to params.
// Assign all recipe parameters to params
params.workdir = recipe['WORKDIR']                              // Where everything is run and output is saved
params.original_genfile_type = recipe['ORIGINAL.GENFILE.TYPE']  // Genotype file type (empty for QC'd data)
params.original_genfile = recipe['ORIGINAL.GENFILE']            // Original genotype file (empty for QC'd data)
params.filtered_bim_prefix = recipe['FILTERED.BIM.PREFIX']      // Filtered by Deepika
params.original_gwas_dir = recipe['ORIGINAL.GWAS.DIR']          // Directory containing original GWAS summary statistics
params.gwas_dir = recipe['GWAS.DIR']                            // Directory containing formatted GWAS files (output of step 1, main input of step 2)
params.population = recipe['POPULATION']                        // Target population
params.phi = recipe['PHI']                                      // PRS-CS shrinkage parameter values
params.masterlist = recipe['MASTERLIST']                        // Info table for GWASs based on summary stats in GWAS folder
params.main_output_dir = recipe['MAINOUTPUTDIR']
params.scores_output_dir = recipe['SCORESOUTPUTDIR']            // Directory where individual PRS scores are stored
params.cluster_file = recipe['CLUSTER.FILE']                    // Environment specific reference parameters
params.cohort_file = recipe['COHORT.FILE']                      // Should be constant, cohort-parameters are picked by the cohort var
params.cluster = recipe['CLUSTER']                              // Used as reference by the Clusters.csv file
params.cohort = recipe['COHORT']                                // Used as reference at the Cohorts.csv file to source cohort specific data
params.superpopulation = recipe['SUPERPOPULATION']              // Used as reference at both Clusters.csv and Cohorts.csv


// modelsDir is used to source the generated models jobs
params.gwas_dir_basename = file(params.gwas_dir).baseName
def modelsDir = (file(params.main_output_dir).resolve(params.gwas_dir_basename))    

// logs_outdir is now analysis specific
def recipeBase = file(params.recipe).baseName   // without extension
params.logs_outdir = file(params.logs_outdir).resolve('logs').resolve(recipeBase)

/*
========================================================================================
    PROCESSES
========================================================================================
*/

process READY_GWAS {
    tag "Format GWAS summary statistics"
    publishDir "${params.logs_outdir}", mode: 'copy', pattern: "*.{out,err}"
    
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
    publishDir "${params.logs_outdir}", mode: 'copy', pattern: "*.{out,err}"
    
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


process DISCOVER_JOB_SCRIPTS {
  tag "discover jobs"
  publishDir "${params.logs_outdir}", mode: 'copy', pattern: "discover_jobs.out"

  input:
  val _
  val models_root

  output:
  path "job_list.txt", emit: list

  script:
  """
  set -euo pipefail
  find "${models_root}" -type f -path "*/jobs/*.sh" -print > job_list.txt
  echo "Found \$(wc -l < job_list.txt) job scripts under ${models_root}" > discover_jobs.out
  """
}


process RUN_JOB_SCRIPT {
  tag { scriptFile.baseName }
  publishDir "${params.logs_outdir}", mode: 'copy', pattern: "*.{out,err}"

  input:
  path scriptFile

  output:
  val true, emit: complete
  path "run_job.out", emit: log_out, optional: true
  path "run_job.err", emit: log_err, optional: true

  // Optionally throttle parallelism: withName:RUN_JOB_SCRIPT { maxForks 8 }
  script:
  """
  set -euo pipefail
  cd "\$(dirname "${scriptFile}")"
  chmod +x "\$(basename "${scriptFile}")" || true
  bash "\$(basename "${scriptFile}")" > run_job.out 2> run_job.err
  """
}





process JOIN_MODELS {
    tag "Join chromosome-specific PRScs models"
    publishDir "${params.logs_outdir}", mode: 'copy', pattern: "*.{out,err}"
    
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
    publishDir "${params.logs_outdir}", mode: 'copy', pattern: "*.{out,err}"
    
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
    Output directory    : ${params.logs_outdir}
    Scripts directory   : ${params.scripts_dir}
    Stored Jobs Dir     : ${modelsDir}
    Logs Dir            : ${params.logs_outdir}
    ========================================================================================
    """

    // Sequential workflow matching your original commands:
    // 1. R1: Format GWAS summary statistics
    READY_GWAS()
    
    // 2. R2: Generate PRScs models (depends on R1)
    GENERATE_MODELS(READY_GWAS.out.complete)

    // Discover all job scripts once models are generated
    DISCOVER_JOB_SCRIPTS(GENERATE_MODELS.out.complete, modelsDir.toString())
    def jobScripts = DISCOVER_JOB_SCRIPTS.out.list.splitText()      // one line -> one item
                            .map { file(it) }                       // cast to Path

    // Run each script (parallel tasks)
    RUN_JOB_SCRIPT(jobScripts)

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
    
    Results can be found in: ${params.logs_outdir}
    
    Pipeline Steps Completed:
    1. ✓ GWAS formatting (PRScs_1.ready_GWAS_CMC.R)
    2. ✓ Model generation (PRScs_2.generate_PRScs_models_phigrid_and_auto_CMC_EUR.PGC.R)
    3. ✓ Model joining (PRScs_3.join_bed-based_PRScs_models_CMC_EUR.PGC.R)
    4. ✓ Individual scoring (PRScs_4.score_bed-based_individuals_CMC_EUR.PGC.R)
    ========================================================================================
    """
}
