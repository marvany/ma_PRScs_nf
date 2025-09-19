#########################
# Generate PRScs models #
# PRScs wrapper by      #
#  Georgios Voloudakis  #
#########################

# Notation for Karen's edits (for PNC iPSYCH PRScs run)
### = Original Georgios' code that Karen commented out 
#### = Karen's comments 

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
if(opt$cluster == "minerva") source("/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/pipeline/R/PRScs_0.settings_handler_CMC_EUR.PGC.R")
#FIXME add the other clusters here as well (or include the PRSscs_0.settings handler here) or write it as a package
PRSCS_settings_handler(
  # defaults are for prototyping
  cluster = opt$cluster,
  cluster.settings.file = opt$clusterfile,
  project.recipe = opt$recipe,
  cohort.settings.file = opt$cohortfile,
  cohort = opt$cohort
)
#PRSCS_settings_handler() # for prototyping

##########################################
# ADDITIONAL PACKAGES AND CUSTOM FUNCTIONS
if (cluster == "genisis") # this will 
  source("/home/home1/vhabrxvoloug/Desktop/Protocols/R.scripts/environment.R")

##############
# MAIN HANDLER

## Files identification
file_vector <- function(x) {
  files <- list.files(x, full.names = T)
  # Get list of files for processing
  if (length(files)==0) { # this means that it is a single file
    if (grepl(".list", x)) {files <- readLines(x) # it is a list load file list
    } else { files <- x } # It is a single file, use x
  } else {}# It is a folder, use files directly
  return(files) }
files <- file_vector(INPUT)

## Finding directories and files
TEMPDIR <- paste0(WORKDIR, "/TEMP")
if (!dir.exists(TEMPDIR)) dir.create(TEMPDIR)
# Defining LD reference directory
if (POP == "EUR") {LDREF <- LDREF.EUR} else {
  if (POP == "AFR") {LDREF <- LDREF.AFR} else {
    if (POP == "AMR") {LDREF <- LDREF.AMR} else {
      if (POP == "EAS") {LDREF <- LDREF.EAS} else {
        if (POP == "SAS") {LDREF <- LDREF.SAS} else {
          if (POP == "EUR.UKBB") {LDREF <- LDREF.EUR.UKBB} else {
            if (POP == "AFR.UKBB") {LDREF <- LDREF.AFR.UKBB} else {
              if (POP == "AMR.UKBB") {LDREF <- LDREF.AMR.UKBB} else {
                if (POP == "EAS.UKBB") {LDREF <- LDREF.EAS.UKBB} else {
                  if (POP == "SAS.UKBB") {LDREF <- LDREF.SAS.UKBB} else {
      stop("No valid population is defined") } } } } } } } } } }  

## Getting GWAS information
gwass <- fread(MASTERLIST) 

MAINOUTPUTDIR <- file.path(MAINOUTPUTDIR, basename(INPUT))
## Submittting the jobs
for (BIMPREFIX in ALLBIMPREFIX) { # models are build for each set of variants.
  if (cluster == "genisis") {
    genbackground  <- basename(dirname(BIMPREFIX))
  } else genbackground  <- basename(BIMPREFIX)
  OUTPUTDIR      <- paste0(MAINOUTPUTDIR, "/", genbackground, "/PRScs/chunks")
  if (!dir.exists(OUTPUTDIR)) dir.create(OUTPUTDIR, recursive = T)
  
  for (thisphi in phi) { # needs to be run for each phi
    if (thisphi != "auto") {
      phicommand <- paste0(" --phi=", thisphi) } else {
        phicommand <- "" }
    
    ### preparing jobs
    for (i in files) {
      not_gzipped = function(x) sub("\\.gz$", "", x) # in case it is stored gzipped
      n_sum       <- gwass[File_name == not_gzipped(basename(i)), "N_sum", with = F]
      prscsname   <- gwass[File_name == not_gzipped(basename(i)), "PRS_abbreviation", with = F]
      destination <- paste0(OUTPUTDIR, "/", prscsname)
      if (!dir.exists(destination)) dir.create(destination)
      jobs        <- paste0(destination, "/jobs")
      if (!dir.exists(jobs)) dir.create(jobs)
      TRAITDIR <- paste0(OUTPUTDIR, "/", prscsname)
      if (!dir.exists(TRAITDIR)) dir.create(TRAITDIR)
      for (chr in 1:22) {
        job.id <- paste0(prscsname, ".", thisphi, ".", chr)
        b.sub  <- paste0(PRSCS.BSUB.PREFIX, 
                         ' -J ', job.id,
                         ' -o ', job.id, '.out',
                         ' -e ', job.id, '.err < ')
        writeLines(
          paste0(
            PRSCS, 
            " --ref_dir=", LDREF,
            " --bim_prefix=", BIMPREFIX,
            phicommand,
            " --sst_file=", i,
            " --n_gwas=", n_sum,
            " --chrom=", chr,
            " --out ", OUTPUTDIR, "/", prscsname, "/", prscsname), 
          paste0(jobs, "/", job.id, ".sh") ) 
        # only run if file doesn't exist
        expected.output <- paste0(
          OUTPUTDIR, "/", prscsname, "/", prscsname,
          "_pst_eff_a1_b0.5_phi",thisphi,"_chr", chr, ".txt")
        #if (!file.exists(expected.output)) {        
        #  system(paste0(
        #    "cd ", jobs, " && ", # so that jobs output comes here 
        #    b.sub, jobs, "/", job.id, ".sh"))
        #}
      } # chr loop ends
    } # files loop ends
    
  } # phi loop ends
} # BIMPREFIX loop ends
