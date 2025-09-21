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

get_entry <- function(key, recipe) {
  v <- recipe[type == key, entry]
  v <- v[!is.na(v) & nzchar(v)]
  if (length(v)) v[[1L]] else ""
}

option_list = list(
  make_option(c("-r", "--recipe"), type="character", default=NULL, 
              help="recipe file name", metavar="character")
) 
#WORKDIR         <- get_entry("WORKDIR",        recipe)
#MASTERLIST      <- get_entry("MASTERLIST",     recipe)
#POPULATION      <- get_entry("POPULATION",     recipe)      # e.g., "EUR.UKBB"
#SUPERPOPULATION <- get_entry("SUPERPOPULATION",recipe)      # e.g., "EUR.UKBB"
#FILTERED_BIM    <- get_entry("FILTERED.BIM.PREFIX", recipe) # may be one or many, comma/space sep
#PHI_STR         <- get_entry("PHI",            recipe)      # e.g., "auto,1e-06,1e-04,1e-02,1e+00"
#SCORESOUTPUTDIR <- get_entry("SCORESOUTPUTDIR",recipe)
#WORKDIR         <- get_entry("WORKDIR", recipe)        # used to make TEMPDIR

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if(FALSE){
  #DEBUG
  library("optparse")
  library("data.table")
  get_entry <- function(key, recipe) {
    v <- recipe[type == key, entry]
    v <- v[!is.na(v) & nzchar(v)]
  if (length(v)) v[[1L]] else ""
  }

  opt <- list(recipe = '/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/pipeline/config/adlerGWAS_UKBB.recipe')

}

if (is.null(opt$recipe)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
}
recipe <- fread(opt$recipe)

cluster         <- get_entry("CLUSTER",        recipe)
CLUSTER_FILE    <- get_entry("CLUSTER.FILE",   recipe)
COHORT_FILE     <- get_entry("COHORT.FILE",    recipe)
COHORT          <- get_entry("COHORT",         recipe)

################
# GET PARAMETERS
if(cluster == "minerva") source("/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/pipeline/R/PRScs_0.settings_handler_CMC_EUR.PGC.R")
#FIXME add the other clusters here as well (or include the PRSscs_0.settings handler here) or write it as a package
PRSCS_settings_handler(
  # defaults are for prototyping
  cluster = cluster,
  cluster.settings.file = CLUSTER_FILE,
  project.recipe = opt$recipe,
  cohort.settings.file = COHORT_FILE,
  cohort = COHORT
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
