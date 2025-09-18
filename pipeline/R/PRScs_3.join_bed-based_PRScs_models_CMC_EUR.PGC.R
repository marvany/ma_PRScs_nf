###############################################################################
# Generate PRScs models                                                       #
#                                                                             #
# - Find expected file and only create if it doesn't exist - can add an       #
# overwrite option later on if I want. This will also help for resubmitting   #
# jobs.                                                                       #
###############################################################################

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

##########################################
# ADDITIONAL PACKAGES AND CUSTOM FUNCTIONS
if (cluster == "genisis") # this will 
  source("/home/home1/vhabrxvoloug/Desktop/Protocols/R.scripts/environment.R")
make_safe <- function(x) return(gsub("([.|()\\^{}+$*?]|\\[|\\])","\\\\\\1",x))

##############
# MAIN HANDLER

# For each genetic background file
for (BIMPREFIX in ALLBIMPREFIX) { # different sources
  if (cluster == "genisis") {
    genbackground  <- basename(dirname(BIMPREFIX))
  } else genbackground  <- basename(BIMPREFIX)
  CHUNKDIR <- paste0(MAINOUTPUTDIR, "/", genbackground, "/PRScs/chunks")
  OUTPUTDIR <- paste0(MAINOUTPUTDIR, "/", genbackground)
  if (!dir.exists(OUTPUTDIR)) dir.create(OUTPUTDIR)
  
  ## For each different phi threshold (global shrinkage parameter)
  for (thisphi in phi) { # different phi thresholds
    
    setwd(OUTPUTDIR)
    
    for (i in list.dirs(CHUNKDIR, full.names = TRUE, recursive = FALSE)) {
      trait <- basename(i)
      expected.file <- paste0(OUTPUTDIR, "/", basename(i), "_phi", thisphi, ".txt")
      
      if (!file.exists(expected.file)) {
        files.to.join <- list.files(i, full.names = TRUE,
                                    # Adjusting the pattern to sub out problematic characters
                                    pattern = make_safe(paste0("pst_eff_a1_b0.5_phi", thisphi, "_chr")))
        
        to.join <- lapply(1:22, FUN = function(x) {
          file_path <- paste0(sub("chr[[:digit:]]+.txt$", "", files.to.join[1]), "chr", x, ".txt")
          
          # Check if the file exists and is not empty before reading it
          if (file.exists(file_path) && file.size(file_path) > 0) {
            return(fread(file_path))
          } else {
            return(NULL)  # Skip empty or non-existing files
          }
        })
        
        # Remove NULL entries from the list
        to.join <- do.call(rbind, to.join[!sapply(to.join, is.null)])
        
        # have to follow specific format for final PRS model
        write.table(to.join,
                    file = expected.file,
                    col.names = F,
                    row.names = F,
                    quote = F,
                    sep = "\t")
      }
    } # done processing
    
  } # phi loop ends
} # BIMPREFIX loop ends
