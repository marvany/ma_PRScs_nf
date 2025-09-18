#########################################
# SIMPLE PLINK WRAPPER FOR PRS SCORING  #
# GEORGIOS VOLOUDAKIS                   #
#########################################

# Notation for Karen's edits (for PNC iPSYCH PRScs run)
### = Original Georgios' code that Karen commented out 
#### = Karen's comments 

DRYRUN=F # T for not submitting the jobs

########################
# LIBRARIES & PARAMETERS
library("optparse")
library("data.table")

option_list = list(
  make_option(c("-r", "--recipe"), type="character", default=NULL, 
              help="recipe file name", metavar="character"),
  make_option(c("-f", "--clusterfile"), type="character", default=NULL, 
              help="Cluster settings file [default= %default]", metavar="character"),
  make_option(c("-c", "--cluster"), type="character", default="genisis", 
              help="Clusters: georgios_local, genisis, minerva [default= %default]", metavar="character"),
  make_option(c("-a", "--cohortfile"), type="character", default=NULL, 
              help="Cohort settings file [default= %default]", metavar="character"),
  make_option(c("-b", "--cohort"), type="character", default="MVP", 
              help="Cohorts: Ruzicka_CMC_minerva, MVP, UKBB [default= %default]", metavar="character"),
  make_option(c("-s", "--superpopulation"), type="character", default="EUR", 
              help="Superpopulation EUR, AFR, AMR, EAS, SAS, EUR.UKBB, AFR.UKBB, AMR.UKBB, EAS.UKBB, SAS.UKBB [default= %default]", metavar="character")
); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$recipe)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
}

################
# GET PARAMETERS
if(opt$cluster == "minerva") source("/sc/arion/projects/va-biobank/PROJECTS/prscs_psychad_nf_v1/R/PRScs_0.settings_handler_CMC_EUR.PGC.R")
### if(opt$cluster == "minerva") source("/sc/arion/projects/va-biobank/Georgios/tools/gentools/modules/PRScs/R/PRScs_0.settings_handler.R")
#FIXME add the other clusters here as well
PRSCS_settings_handler(
  # defaults are for prototyping
  cluster = opt$cluster,
  cluster.settings.file = opt$clusterfile,
  project.recipe = opt$recipe,
  cohort.settings.file = opt$cohortfile,
  cohort = opt$cohort
)
#PRSCS_settings_handler() # for prototyping

##################################
# PREPARE TASK SPECIFIC PARAMETERS
library(stringr)
MAINMODELSDIR  <- MAINOUTPUTDIR
NEWOUTPUTDIR   <- paste0(SCOREOUTPUTDIR, "/indiv.files")
if (!dir.exists(NEWOUTPUTDIR)) dir.create(NEWOUTPUTDIR)
PLINK.EXEC     <- PLINK2.EXEC

##############
# MAIN HANDLER
# For each genetic background file
for (BIMPREFIX in ALLBIMPREFIX) { # different sources
  if (cluster == "genisis") {
    genbackground  <- basename(dirname(BIMPREFIX))
  } else genbackground  <- basename(BIMPREFIX)
  MODELSDIR   <- paste0(MAINMODELSDIR, "/", genbackground)
  ## We will generate SNP extraction lists for each model to filter
  ## the genotype files.
  EXTRACTLIST   <- paste0(MODELSDIR, "/VARIANTS")
  if (!dir.exists(EXTRACTLIST)) dir.create(EXTRACTLIST, recursive=T)
  ## For each different phi threshold (global shrinkage parameter)
  for (thisphi in phi) { # different phi thresholds
    ### Generating and submitting the scripts
    for (y in list.files(MODELSDIR, full.names = T, recursive = F,
                         include.dirs = F, pattern = ".txt$")) {
      # check for variant extraction lists and generate them if they don't exist
      EXTRACT.FILE <- paste0(EXTRACTLIST, "/", basename(y))
      if (!file.exists(EXTRACT.FILE)) {
        fread.fam <- function(x) fread(x, header=F)
        EXTRACT <- fread.fam(y)$V2
        writeLines(EXTRACT, EXTRACT.FILE) }
      thisphi <- stringr::str_extract(y, "([[:digit:]]+e.[[:digit:]]+|auto)")    
      trait <- sub("_phi([[:digit:]]+e.[[:digit:]]+|auto).txt", "", basename(y))
      expected.file <- paste0(
        NEWOUTPUTDIR, "/", genbackground, "...", trait, "...",
        "phi", thisphi, ".sscore")
      jobs.dir <- paste0(NEWOUTPUTDIR, "/JOBS")
      if (!dir.exists(jobs.dir)) dir.create(jobs.dir)
      job.id    <- sub(".sscore$", "", basename(expected.file))
      if (!file.exists(expected.file)) {
        b.sub <- paste0(
          PLINK2.BSUB, ' ',
          '-J ', job.id, ' ',
          '-o ', job.id, '.out -e ', job.id, '.err <')
        # prepares script then executes
        plink.command <- paste0(
          "cd ",NEWOUTPUTDIR, "\n",
          PLINK2.PREPARATION,
          PLINK.EXEC,
          " --bfile ", BIMPREFIX, " ",
          PLINK2.PARAMETERS, " ",
          # Selection of individuals for population
          ## Forcing to EUR here

          paste0("--keep ", PLINK2.EUR.KEEP.IDS, ".fam "),
    
          # Extract variants
          " --extract ", EXTRACT.FILE, # this saves so much time especially in genisis
          " --out ", NEWOUTPUTDIR, "/", job.id,
          #" --score ", y, " 2 4 6"
          " --score ", y, " 2 4 6 'list-variants'" # add 'list-variants' modifier!
        )
        writeLines(paste0("#!/bin/bash", "\n",plink.command), 
                   paste0(jobs.dir, "/", job.id, ".plink.sh"))
        if (!DRYRUN) { # if dry run then don't execute the scripts
          system(paste(
            "cd ", jobs.dir, " && ", # so that jobs output comes here 
            b.sub, paste0(job.id, ".plink.sh"))) }  
      } # what to do if expected score file does not exist.
    } # done processing all prs models
  } # phi loop ends
} # BIMPREFIX loop ends
