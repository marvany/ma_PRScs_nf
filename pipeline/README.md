# prscs_psychad_nf_v1

Nextflow pipeline and R scripts for PRS-CS processing on Minerva (LSF).
This repo contains code and configuration only — no large data or results.


# PRS-CS Nextflow Pipeline Documentation

## Pipeline Overview
This pipeline automates PRS-CS (Polygenic Risk Score using Continuous Shrinkage priors) workflow for calculating polygenic risk scores from GWAS summary statistics.

## Setup and Execution

### Step 1: Environment Setup
```bash
source setup_v3.sh
```
**Note:** Use `setup_v3.sh` instead of `setup.sh` as indicated in older documentation. This script loads all required modules and sets up the environment correctly.

### Step 2: Run Pipeline
```bash
run_pipeline 'TRAIT_NAME' 'PHI_VALUES'
```

## Configuration Files

### Recipe File Configuration
The recipe file controls most input parameters for the pipeline. It's specified in `nextflow.config`:
- Location is defined via the `recipe` parameter in `nextflow.config`
- Contains CSV format with type, entry, and notes columns

#### Recipe File Parameters:

| Parameter | Description | Notes |
|-----------|-------------|-------|
| **WORKDIR** | `/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/results/work` | Scratch space for temporary files during pipeline execution |
| **ORIGINAL.GENFILE.TYPE** | - | Should be left empty (for already QC'd data) |
| **ORIGINAL.GENFILE** | - | Should be left empty (for already QC'd data) |
| **FILTERED.BIM.PREFIX** | `/sc/arion/projects/roussp01b/deepika/psychAD_QC_PRS/variant_level_QC/psychAD_1469_samples.recode_formatted_R2_0.8_ALFA_MAF_EUR_0.01_only_EUR_samples_HWE_1e-6_geno_0.02` | Points to individual-level SNPs that have been pre-QC'd |
| **ORIGINAL.GWAS.DIR** | `/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/gwas_original` | Directory containing original GWAS summary statistics |
| **GWAS.DIR** | `/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/gwas_formatted` | This is the actual GWAS input; contains TSV files with summary statistics |
| **POPULATION** | `EUR` | Target population |
| **PHI** | `auto,1e-06,1e-04,1e-02,1e+00` | PRS-CS shrinkage parameter values |
| **MASTERLIST** | `/sc/arion/projects/va-biobank/Georgios/tools/gentools/settings/rachel_GWAS_master_list.csv` | Info table for GWASs; needs updating based on available summary stats in GWAS folder |
| **MAINOUTPUTDIR** | `/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/results/models` | Directory where PRS model weights are stored |
| **SCORESOUTPUTDIR** | `/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/results/scores` | Directory where individual PRS scores are stored |

### Nextflow Configuration Parameters

Parameters in `nextflow.config` file:

| Parameter | Description | Notes |
|-----------|-------------|-------|
| **recipe** | Path to recipe file | Contains most pipeline parameters (see above) |
| **scripts_dir** | Directory with R scripts | Points to location of pipeline scripts |
| **outdir** | Output directory | For Nextflow outputs (e.g., log files) |
| **gwas_formatted_dir** | Intermediate storage | Where formatted GWAS files are stored as pipeline intermediate |
| **clusters.csv** | Cluster configuration | Contains reference files; constant for HPC environment |
| **superpopulation** | Target population | Points to target population (e.g., EUR) |
| **cohort** | Cohort identifier | Used as reference in Cohorts.csv file |

## Key Notes

- When running `run_pipeline 'TRAIT_NAME'`, the TRAIT_NAME must match a file in GWAS.DIR
- Example: `run_pipeline 'C4_REGION_ONLY_SCZ_Trubetskoy' 'auto,1e-06,1e-04,1e-02,1e+00'`
- The GWAS file is expected to be a TSV file containing summary statistics
- The master list should be updated to reflect available GWAS summary statistics

## Directory Structure

```
/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/
├── config/
│   ├── 2022-12-07_CMC_TOPMed_updated_EUR.PGC.recipe  # Main recipe file
│   ├── Clusters.csv                                    # HPC reference files
│   └── Cohorts.csv                                     # Cohort definitions
├── gwas_original/                                      # Original GWAS files
├── gwas_formatted/                                     # Formatted GWAS files
├── results/
│   ├── work/                                          # Temporary/scratch files
│   ├── models/                                        # PRS model weights
│   └── scores/                                        # Individual PRS scores
└── nextflow.config                                    # Pipeline configuration
```

## Troubleshooting

- Ensure all paths in the recipe file are accessible
- Check that GWAS files exist in the specified directories
- Verify the master list matches available GWAS summary statistics
- For missing results, check if outputs from previous steps match inputs to subsequent steps (as files may be scattered across directories)