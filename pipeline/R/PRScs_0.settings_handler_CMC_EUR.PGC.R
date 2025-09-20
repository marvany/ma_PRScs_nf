#####################################
# PRSCS SETTINGS HANDLER            #
# Simplified handling of parameters #
# Georgios Voloudakis               #
#####################################

# Notation for Karen's edits 
### = Original Georgios' code that Karen commented out
#### = Karen's comments

PRSCS_settings_handler <- function(
  # defaults are for prototyping
  cluster = "minerva",
  cluster.settings.file = "/sc/arion/projects/va-biobank/PROJECTS/prscs_psychad_nf_v1/config/Clusters.csv",
  cohort = "psychAD_EUR",
  cohort.settings.file = "/sc/arion/projects/va-biobank/PROJECTS/prscs_psychad_nf_v1/config/Cohorts.csv",
  project.recipe = "/sc/arion/projects/va-biobank/PROJECTS/prscs_psychad_nf_v1/config/2022-12-07_CMC_TOPMed_updated_EUR.PGC.recipe"
  
) {
  #######################
  # LOAD CLUSTER SETTINGS
  # setwd("/sc/hydra/projects/CommonMind/roussp01a/eRNA/PRS")
  # cluster               <- opt$cluster # cluster <- "minerva"
  # cluster.settings.file <- opt$clusterfile # cluster.settings.file <- "/home/georgios/Tools/gentools/settings/Clusters.csv"
  cluster.settings      <- fread(cluster.settings.file)
  cluster.settings      <- cluster.settings[,c("type",cluster ), with = F]
  #### ^pulls out info for cluster noted above
  LDREF.EUR             <- cluster.settings[type=="PRSCS.LDREF.EUR"][[cluster]]
  LDREF.AFR             <- cluster.settings[type=="PRSCS.LDREF.AFR"][[cluster]]
  LDREF.AMR             <- cluster.settings[type=="PRSCS.LDREF.AMR"][[cluster]]
  LDREF.EAS             <- cluster.settings[type=="PRSCS.LDREF.EAS"][[cluster]]
  LDREF.SAS             <- cluster.settings[type=="PRSCS.LDREF.SAS"][[cluster]]
  LDREF.EUR.UKBB        <- cluster.settings[type=="PRSCS.LDREF.EUR.UKBB"][[cluster]]
  LDREF.AFR.UKBB        <- cluster.settings[type=="PRSCS.LDREF.AFR.UKBB"][[cluster]]
  LDREF.AMR.UKBB        <- cluster.settings[type=="PRSCS.LDREF.AMR.UKBB"][[cluster]]
  LDREF.EAS.UKBB        <- cluster.settings[type=="PRSCS.LDREF.EAS.UKBB"][[cluster]]
  LDREF.SAS.UKBB        <- cluster.settings[type=="PRSCS.LDREF.SAS.UKBB"][[cluster]]
  PREPARATION           <- cluster.settings[type=="PRSCS.PREPARATION"][[cluster]]
  PRSCS                 <- cluster.settings[type=="PRSCS.EXEC"][[cluster]]
  PRSCS.BSUB.PREFIX     <- cluster.settings[type=="PRSCS.BSUB"][[cluster]]
  PLINK2.PREPARATION    <- cluster.settings[type=="PLINK2.PREPARATION"][[cluster]]
  PLINK2.EXEC           <- cluster.settings[type=="PLINK2.EXEC"][[cluster]]
  PLINK2.BSUB           <- cluster.settings[type=="PLINK2.BSUB"][[cluster]]
  PLINK2.PARAMETERS     <- cluster.settings[type=="PLINK2.PARAMETERS"][[cluster]] 
  
  ######################
  # LOAD COHORT SETTINGS
  cohort.settings       <- fread(cohort.settings.file)
  PLINK2.EXCLUDE.SNPS   <- cohort.settings[type=="PLINK2.EXCLUDE.SNPS"][[cohort]]
  PLINK2.EUR.KEEP.IDS   <- cohort.settings[type=="PLINK2.EUR.KEEP.IDS"][[cohort]]
  PLINK2.EUR.REMOVE.IDS <- cohort.settings[type=="PLINK2.EUR.REMOVE.IDS"][[cohort]]
  PLINK2.AFR.KEEP.IDS   <- cohort.settings[type=="PLINK2.AFR.KEEP.IDS"][[cohort]]
  PLINK2.AFR.REMOVE.IDS <- cohort.settings[type=="PLINK2.AFR.REMOVE.IDS"][[cohort]]
  PLINK2.AMR.KEEP.IDS   <- cohort.settings[type=="PLINK2.AMR.KEEP.IDS"][[cohort]]
  PLINK2.AMR.REMOVE.IDS <- cohort.settings[type=="PLINK2.AMR.REMOVE.IDS"][[cohort]]
  PLINK2.EAS.KEEP.IDS   <- cohort.settings[type=="PLINK2.EAS.KEEP.IDS"][[cohort]]
  PLINK2.EAS.REMOVE.IDS <- cohort.settings[type=="PLINK2.EAS.REMOVE.IDS"][[cohort]]
  PLINK2.SAS.KEEP.IDS   <- cohort.settings[type=="PLINK2.SAS.KEEP.IDS"][[cohort]]
  PLINK2.SAS.REMOVE.IDS <- cohort.settings[type=="PLINK2.SAS.REMOVE.IDS"][[cohort]]
  
  #######################
  # LOAD PROJECT SETTINGS
  # project.recipe <- opt$recipe # project.recipe <- "/home/georgios/Tools/gentools/modules/PRScs/0.Project_recipes/2020-04-28_eRNA.recipe"
  recipe         <- fread(project.recipe) # fwrite(recipe, project.recipe)
  INPUT          <- recipe[type == "GWAS.DIR"]$entry # genisis "/group/research/mvp006/data/PRScs/GWAS_formatted"
  phi            <- unlist(strsplit(recipe[type == "PHI"]$entry, split=",")) # default #  c("auto", "1e-06","1e-04","1e-02","1e+00") # phi=1e-6,1e-4,1e-2,1
  ALLBIMPREFIX   <- unlist(strsplit(recipe[type == "FILTERED.BIM.PREFIX"]$entry, split=","))
  POP            <- recipe[type == "POPULATION"]$entry
  WORKDIR        <- recipe[type == "WORKDIR"]$entry
  MASTERLIST     <- recipe[type == "MASTERLIST"]$entry
  MAINOUTPUTDIR  <- recipe[type == "MAINOUTPUTDIR"]$entry; if (!dir.exists(MAINOUTPUTDIR)) dir.create(MAINOUTPUTDIR, recursive = T)
  SCOREOUTPUTDIR <- recipe[type == "SCORESOUTPUTDIR"]$entry; if (!dir.exists(SCOREOUTPUTDIR)) dir.create(SCOREOUTPUTDIR, recursive = T)
  
  #############################
  # BRING TO GLOBAL ENVIRONMENT
  ## Package the payload
  LIST <- mget(ls())
  ## Send payload to the global environment
  list2env(LIST, envir = .GlobalEnv)
  
}

#PRSCS_settings_handler()
