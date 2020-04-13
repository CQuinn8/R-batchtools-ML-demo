# Purpose: imports all batchtools model fits, predictions, and stats

.libPaths()
ll = .libPaths()[1]
library(rlang, lib.loc = ll) # a dependency for BT that sometimes causes errors
library(batchtools, lib.loc = ll) # creates schedule enviro
library(namedCapture, lib.loc = ll) # dependency
library(caret, lib.loc = ll) # multiple ML algos
library(earth, lib.loc = ll) # specific ML algo
library(WeightedROC, lib.loc = ll) # error analysis
library(data.table, lib.loc = ll) # data organization library
library(e1071, lib.loc = ll)
library(ranger, lib.loc = ll)

# Working directory space on monsoon
userID = "" # e.g. abc123
wd = paste0("/home/", userID, "/ecoinf/R-batchtools-ML-demo/")
reg.dir <- paste0(wd, "registry-demo")

#import primary registry
reg <- loadRegistry(reg.dir)

#directory to save products to
moddir <- wd

spp.csv.vec <- normalizePath(Sys.glob("data/*.csv"))

print(paste('Species dir:',spp.csv.vec[1])) #verify imported spp are correct

all.y.list <- list()
all.X.list <- list()
species.name.vec <- c(
  "123"="Table Mountain Pine",
  "318"="Sugar Maple"
)

names(species.name.vec) <- paste0("spp_env_12km_", names(species.name.vec), ".csv")

#reading in pred/response tables
for(spp.csv in spp.csv.vec[1:2]){
  spp <- fread(spp.csv)[c(1:10000),]
  species <- species.name.vec[basename(spp.csv)]
  all.y.list[[species]] <- spp$PRES
  all.X.list[[species]] <- as.matrix(spp[, 6:28])
}

# retrieve all job info
job.table <- getJobTable()
job.table[, test.fold := sapply(prob.pars, "[[", "test.fold")]

#separate complete jobs
done <- getJobTable()[!is.na(done)]

for(name in names(done$prob.pars[[1]])){
  done[[name]] <- sapply(done$prob.pars, "[[", name)
}

n.folds <- max(done$test.fold)
done[, species := species.name.vec[paste(basename(spp.csv))]] # assign species common name, will feed back an error, but works fine
done[, table(algorithm)] #algo type
done[, table(basename(spp.csv), species)] 

# get an example of the results generated 
test.set.info <- done[1]
algo.name <- test.set.info$algorithm

# Section to pull algo meta data
algo.meta <- data.table(jobid =test.set.info$job.id, 
                        algo = test.set.info$algorithm, 
                        spp = test.set.info$species, 
                        testfold = test.set.info$test.fold)
algo.result <- loadResult(test.set.info)

# some score statistics
algo.result$TP
algo.result$FP
algo.result$TN
algo.result$FN
algo.result$auc
algo.result$tss
