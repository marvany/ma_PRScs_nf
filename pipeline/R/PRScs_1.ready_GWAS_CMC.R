# Possible steps
# 1) can do a log(OR) to see if it drops closer to 0 or 1 and thus decide if it needs transformation
# 2) Remove all p values with NA, null, etc.
# 3) filter out those that don't have rs ids
# We just need SNP, A1, A2, OR/BETA, P
# where SNP is the rs ID, A1 is the reference/effect allele, A2 is the alternative allele, BETA/OR is the effect/odds ratio of the reference allele, P is the p-value of the effect. In fact, BETA/OR is only used to determine the direction of an association, and therefore if z-scores or even +1/-1 indicating effect directions are presented in the BETA column, the algorithm should still work properly.
# https://www.biostars.org/p/310841/ for definitions of alleles

# Notation for Karen's edits 
### = Georgios' code that Karen commented out
#### = Karen's comments
##### = Whoever's code that Marios commented out
## --------------------------------- NEXTFLOW ADDITIONS

get_entry <- function(key, recipe) {
  v <- recipe[type == key, entry]
  v <- v[!is.na(v) & nzchar(v)]
  if (length(v)) v[[1L]] else ""
}

option_list <- list(
  make_option("-r", "--recipe",     type = "character", help = "Recipe"),
  make_option("-f", "--firstrun",  type = "logical", default = FALSE,
              help = "First pass to inspect headers and write column.types.tsv [default %default]"),
  make_option("output", "--formattedGWASdir",    type = "character", default = "/sc/arion/projects/va-biobank/PROJECTS/ma_PRScs_nf/input_gwas/gwas_formatted/",
              help = "OUTPUTDIR (directory to write formatted GWAS files)"),
  make_option("-c", "--coltypes",  type = "character", default = "/sc/arion/projects/va-biobank/Georgios/tools/gentools/modules/PRScs/resources/GWAS.column.types.csv",
              help = "CSV mapping of column names to Types"),
  make_option("-conv", "--convdir",   type = "character", default = "/group/research/mvp006/data/PRScs/Conversion_files",
              help = "Directory holding/where to write conversion tables"),
  make_option("-cl", "--cluster",   type = "character", default = "minerva",
              help = "Cluster name toggle for behavior (e.g., minerva | genisis)"),
  make_option("-wd", "--wd",     type = "character", default = "/sc/arion/projects/va-biobank/PROJECTS/prscs_psychad_nf_v1",
              help = "Working directory to set at start")
)

opt <- parse_args(OptionParser(option_list = option_list))

### Settings
setwd(opt$wd)  

recipe              <- opt$recipe
firstrun            <- isTRUE(opt$firstrun) 
INPUTGWASDIR       <- get_entry("GWAS.DIR", recipe)   # input GWAS (ORIGINAL.GWAS.DIR)
OUTPUTDIR           <- opt$formattedGWASdir           # formatted GWAS will be stored here
CONVERSIONTABLESDIR <- opt$convdir


WORKDIR               <- get_entry("WORKDIR", recipe)
ORIGINAL.GENFILE.TYPE <- get_entry("ORIGINAL.GENFILE.TYPE", recipe)
ORIGINAL.GENFILE      <- get_entry("ORIGINAL.GENFILE", recipe)
FILTERED.BIM.PREFIX   <- get_entry("FILTERED.BIM.PREFIX", recipe)
ORIGINAL.GWAS.DIR     <- get_entry("ORIGINAL.GWAS.DIR", recipe)
INPUTGWASDIR          <- get_entry("GWAS.DIR", recipe)
POPULATION            <- get_entry("POPULATION", recipe)
MASTERLIST            <- get_entry("MASTERLIST", recipe)
MAINOUTPUTDIR         <- get_entry("MAINOUTPUTDIR", recipe)   # weights
SCORESOUTPUTDIR       <- get_entry("SCORESOUTPUTDIR", recipe) # scores





message(sprintf("firstrun=%s\nINPUTGWASDIR=%s\nOUTPUTDIR=%s\nCOLUMNTYPES=%s\nCONVERSIONTABLESDIR=%s\ncluster=%s",
                firstrun, recipe, OUTPUTDIR, COLUMNTYPES, CONVERSIONTABLESDIR, cluster))

### setwd("/group/research/mvp006/data/PRScs")
##### firstrun = F
ipsych_conv_table_loc = "/group/research/mvp006/data/PRScs/Conversion_files" # iPSYCH_xDx_sumStats.conv.table locations
##### OUTPUTDIR <- "/sc/arion/projects/va-biobank/PROJECTS/prscs_psychad_nf_v1/gwas_formatted/"
### OUTPUTDIR <- "/group/research/mvp006/data/PRScs/GWAS_formatted"
##### COLUMNTYPES <- "/sc/arion/projects/va-biobank/Georgios/tools/gentools/modules/PRScs/resources/GWAS.column.types.csv"
### COLUMNTYPES <- "/home/home1/vhabrxvoloug/Desktop/Protocols/PRScs/GWAS.column.types.csv"
##### INPUTGWASDIR <- "/sc/arion/projects/va-biobank/PROJECTS/prscs_psychad_nf_v1/gwas_original/"
### INPUTGWASDIR <- "/group/research/mvp006/data/PRScs/GWAS_original"
##### cluster <- "minerva"
CONVERSIONTABLESDIR <- "/group/research/mvp006/data/PRScs/Conversion_files"
DONOTPROCESS <- c( ### Final exclusion list and why
  "cd-meta.txt",               # does not have A2
  "pgc.bip.clump.2012-04.txt",
  "ucmeta-sumstats.txt")       # does not have A2
ORPROPERORDER <- c("SNP", "A1", "A2", "OR", "P")
BETAPROPERORDER <- c("SNP", "A1", "A2", "BETA", "P")
###
# try h2o.import.file

### Packages etc.
source("/sc/arion/projects/va-biobank/Georgios/tools/gentools/scripts/environment_minerva_configured.R")
columntypes <- fread(COLUMNTYPES)
columntypes <- columntypes[Type %in% c("SNP", "A1", "A2", "OR", "lnOR", "BETA", "P"), c("Column.name", "Type"), with = F]
columntypes <- as.data.frame(columntypes)
rownames(columntypes) <- columntypes$Column.name


## First run: get header information for all files ##
if (firstrun) { # first run
  x.directory <- "/sc/arion/projects/roussp01b/rachel/PRScs_SCZ_C4_only/GWAS_ORIGINAL/"
  files <- data.frame(
    files = list.files(x.directory, full.names = T, recursive = T),
    size = file.size(list.files(x.directory, full.names = T, recursive = T))/(1024^2)
  ); setDT(files)
#  files <- files[size>1] # remove readme files
  files <- files[(!grepl("readme", files))] # again remove readme files
  files <- files[(!grepl(".pdf", files))] # again remove readme/pdf files
  #i = files$files[1]
  #names(fread(i))
  all.names <- lapply(files$files, FUN = function(x){names(fread(x))})
  names(all.names)<- basename(files$files)
  writeLines(basename(files$files), "just.names.txt")
  saveRDS(all.names, "all.names.list.RDS")
  all.names <- readRDS("all.names.list.RDS")
  x<- unique(unlist(all.names))
  WriteProperTSV(x, "column.types.tsv")
  stop("Files for column inspection were generated")
} # first run done

#### Get list of GWASs
files <- data.frame(
  files = list.files(INPUTGWASDIR, full.names = T, recursive = T),
  size = file.size(list.files(INPUTGWASDIR, full.names = T, recursive = T))/(1024^2)
); setDT(files)
# files <- files[size>1] # remove readme files  # disabled for small test files
files <- files[(!grepl("readme", files))]
files <- files[(!grepl("pdf$", files))]

# prototyping
# i = 0
# test <- c(files$files,
#  paste0(INPUTGWASDIR, "/MA.gwama_.out_.isq75.nstud6_.clean_.p1e-5_0.txt"),
#  paste0(INPUTGWASDIR, "/MO.gwama_.out_.isq75.nstud6_.clean_.p1e-5_0.txt"))
# i = i +1

#### Prepare GWAS for PRSCS
#sink(paste0(OUTPUTDIR, "/log.txt"))
for (filename in c(files$files#,
                   #paste0(INPUTGWASDIR, "/MA.gwama_.out_.isq75.nstud6_.clean_.p1e-5_0.txt"),
                   #paste0(INPUTGWASDIR, "/MO.gwama_.out_.isq75.nstud6_.clean_.p1e-5_0.txt")
)) {
  message(paste0("Now processing: ", basename(filename)))
  # prototyping  #i = 0
  #i = i+1; filename <- files$files[i]; files$files[i]; filename %in% DONOTPROCESS
  if (basename(filename) %in% DONOTPROCESS) {message("This file is in the exclusion list")} else { #continue
    if (!file.exists(paste0(OUTPUTDIR,"/", basename(filename)))) {
      if (basename(filename) == "pgcAN2.2019-07.vcf.tsv") {
        x <- fread(filename, skip = "CHROM\t") } else {
          if (cluster == "genisis") {
            x   <- fread(filename) } else {
              x   <- fread(filename, nThread = (parallel::detectCores() - 1))
            }
        }
      ## Special rules for a GWAS that doesn't have rsids
      if (basename(filename) %in% c( # When I need to find rsids
        "iPSYCH_xDx_sumStats.txt")) {
        x$coor <- paste(x$CHR, x$BP, sep = ":") # prepare coordinates
        if (!file.exists(paste0(CONVERSIONTABLESDIR,"/iPSYCH_xDx_sumStats.conv.table.1.tsv"))) {
          # check if conversion table exists, if not create it
          ref19 <- fread("/home/georgios/RAW_DATA/ref/Variants_hg/hg19_coor.tsv")
          x <- x[ref19, on = "coor", nomatch=0]
          x$SNP <- x$ID
          x <- x[grep("^rs[[:digit:]]+_", x$SNP), ] # to save the conversion table the first time
          conv.table <- x[, c("coor", "ID"), with = F]
          # split into two files so that they are <100MB
          split.n <- 2; n.rows <- nrow(conv.table)
          for (i in 1:split.n) {
            if (i==1) { y <- conv.table[1:(i*ceiling(n.rows/split.n)), ] } else {
              if (i==split.n) { y <- conv.table[(((i-1)*ceiling(n.rows/split.n))+1):n.rows, ] } else {
                y <- conv.table[(((i-1)*ceiling(n.rows/split.n))+1):(i*ceiling(n.rows/split.n)), ] } }
            fwrite(y, file = paste0("/home/georgios/RAW_DATA/ref/Variants_hg/iPSYCH_xDx_sumStats.conv.table.", i, ".tsv"),
                   sep = "\t", nThread = (parallel::detectCores() - 1)) } # split and save the file
        } else { # just use conversion table if it exists
          ctlist <- list.files(path = CONVERSIONTABLESDIR, pattern = "iPSYCH_xDx_sumStats\\.conv\\.table." , full.names = T)
          ctlist <- lapply(ctlist, fread)
          ct <- rbindlist(ctlist)
          x <- x[ct, on = "coor", nomatch=0]
          x$SNP <- x$ID
          rm(ctlist); rm(ct); gc() } } # save memory
      ## Continue scripts
      x         <- x[,!is.na(columntypes[names(x),"Type"]), with = F] # only keep important columns
      names(x)  <- columntypes[names(x),"Type"] # use the converted names
      # x
      # Will test if I have everything I need
      if (!any(length(intersect(names(x), ORPROPERORDER)) == length(ORPROPERORDER),
               length(intersect(names(x), BETAPROPERORDER)) == length(BETAPROPERORDER))) {
        message("We are missing data, I will see if I have enough data to calculate what I need")
        # https://huwenboshi.github.io/data%20management/2017/11/23/tips-for-formatting-gwas-summary-stats.html
        stop("I don't know how to process this file")
      }
      
      if (any(names(x) == "OR")) {  # Check if it is OR that it is most likely properly
        message("We have OR, I will run a test to see if it is log transformed.")
        ortest <- median(x$OR, na.rm = T)
        if (ortest > 0.9) { message("Regular OR.") } else {
          message("Probably lnOR, will transform.")
          x$OR <- exp(1)^x$OR } } # if it was logarithmic
      x$A1 <- toupper(x$A1); x$A2 <- toupper(x$A2)            # capitalize alleles
      x <- x[!is.na(x$P),]                                    # filter out NA pvalues
      x <- x[grep("^rs[[:digit:]]+", x$SNP), ]                # keep only the ones with rsids
      x$SNP <- stringr::str_extract(x$SNP, "^rs[[:digit:]]+") # extract the rsids from all
      # rearrange before saving
      if (any(names(x) == "OR"))   {x <- x[, ORPROPERORDER,   with = F] }
      if (any(names(x) == "BETA")) {x <- x[, BETAPROPERORDER, with = F] }
      if (cluster == "genisis") {
        WriteProperTSV(x, paste0(OUTPUTDIR,"/", basename(filename))) } else {
          fwrite(x, file = paste0(OUTPUTDIR,"/", basename(filename)),
                 sep = "\t", nThread = (parallel::detectCores() - 1)) }
    } # only did files that do not exist
  } # finish the processing of the files that need to be processed
} # stop looping for files
#sink()
