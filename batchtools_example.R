# Title: batchtools scheduling package used to help with large Monsoon arrays
# Author: Colin Quinn (cq73@nau.edu; modified by code provided by Toby Hocking)
# School of Informatics, Computing, and Cyber Systems, NAU
# Created: 6-January-2020

### SECTION 1 #################################
### Load libraries and set WD

# best to download the versions of packages you need to a location, for the demo these have been copied
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

### SECTION 2 #################################
### Batchtools implementation and setup

# registry, this must be a new pathway that is not yet created on monsoon (i.e. "/scratch/<user>/registry-demo")
reg.dir <- paste0(wd, "registry-demo")

# Run to delete a previous registry
if(FALSE){
  unlink(reg.dir, recursive = TRUE)
}

# Before creating your registry make sure to define cluster functions with this template
if(FALSE){ 
  #put this in your ~/.batchtools.conf.R:
  cluster.functions = makeClusterFunctionsSlurm(paste0(wd,"slurm-afterok.tmpl"))
}

# Creating your registry (should see: > Sourcing configuration file '')
reg <- if(file.exists(reg.dir)){
  loadRegistry(reg.dir)
}else{
  makeExperimentRegistry(reg.dir)
}

# number of external folds
n.folds <- 10

### SECTION 3 #################################
### Data prep
# Define data sets/files here
spp.csv.vec <- normalizePath(Sys.glob("data/*.csv"))

# Initializes all the variables in the next function with a single file,
#  for interactive testing.
spp.csv <- spp.csv.vec[1]
spp <- fread(spp.csv[1])[c(1:10000),]# reducing the size of example csvs for demo to 1000 observations
all.X.mat <- as.matrix(spp[, 6:28]) # all predictor variables in a matrix
all.y.vec <- spp$PRES # response variable as a vector


### SECTION 4 #################################
### Detailed BT setup
# Setting up modeling and batchtools environment
# create training/testing split
some.i <- as.integer(sapply(c(0,1), function(y)which(all.y.vec==y)[1:10]))

# create splits in small.instance for interactive testing
small.instance <- list(
    train.X.mat=all.X.mat[some.i,],
    train.y.vec=all.y.vec[some.i],
    #  note: here, data are binary and need differing responses to work (obs 28 and 29)
    test.X.mat=all.X.mat[8065:8066,],
    is.train="foo",
    test.y.vec = all.y.vec[8065:8066])

# at the bottom of this chunk, training and testing data are created for all species
addProblem("cv", reg=reg, fun=function(job, data, spp.csv, test.fold, n.folds, ...){
  species.id <- namedCapture::str_match_variable(
    spp.csv,
    "_",
    id="[0-9]+")
  spp <- data.table::fread(spp.csv) # reducing size of csv
  all.X.mat <- as.matrix(spp[, 6:28]) # make sure this matches your variables
  all.y.vec <- spp$PRES

  set.seed(1)
  all.fold.vec <- sample(rep(1:n.folds, l=nrow(all.X.mat)))
  is.train <- all.fold.vec != test.fold
  
  # here you can input each species or unit of interest in the vector
  species.name.vec <- c(
    "123"="Table Mountain Pine",
    "318"="Sugar Maple"
    )
  
  train.y.vec <- all.y.vec[is.train]
  response.tab <- table(train.y.vec)
  other.tab <- response.tab #need to assign weights to other class.
  names(other.tab) <- rev(names(response.tab))
  response.dec <- sort(response.tab, decreasing=TRUE)
  major.prob <- as.integer(names(response.dec)[1])
  #large.weight.vec <- as.numeric(other.tab[paste(train.y.vec)])
  #weight.list <- list(
  #  balanced=large.weight.vec,
  #  one=rep(1, length(large.weight.vec)))
  some.i <- as.integer(
    sapply(c(0,1), function(y)which(train.y.vec==y)[1:10]))
  some.i <- seq_along(train.y.vec)
  list(
    is.train=is.train,
    species.name=species.name.vec[species.id],
    train.X.mat=all.X.mat[is.train,][some.i,],
    train.y.vec=train.y.vec[some.i],
    #train.weight.vec=weight.list[[weight.name]][some.i],
    test.X.mat=all.X.mat[!is.train,],
    test.y.vec=all.y.vec[!is.train])
})

# what each ML algorithm will use for setup and how BT runs the R code
makeFun <- function(expr){
  e <- substitute(expr)
  function(instance, ...){
    eval(e, instance)
  }
}

### SECTION 5 #################################
### ML algos

# specifies the functions to carry out on the data created in the addProblem above for each job
# once jobs are submitted, the above problem instantiates these functions for each job array task
pred.fun.list <- list(

  # algorithm 1
  RF = makeFun({

    # bring in data
    ml.Data <- data.frame(label = train.y.vec,
                          train.X.mat,
                          check.names = FALSE)

    #set parameters for ranger RF model
    grid <- expand.grid(.mtry = c(2,3,5,7),
                        .splitrule = c("extratrees"),
                        .min.node.size = c(1,3,5))

    # set cross validation folds
    RF_trctrl <- caret::trainControl(method = "cv",
                                     number = 10)
    # model statement
    RF_fit <- caret::train(label ~ .,
                           data = ml.Data,
                           method = "ranger",
                           importance = "permutation",
                           num.trees = 500,
                           tuneGrid = grid,
                           preProcess = c("center", "scale"),
                           trControl = RF_trctrl,
                           num.threads = 1 # specify number of threads (cores) required
                           )

    # predict on hold-out
    pred.prob.vec <- predict(RF_fit, newdata = test.X.mat)

    #Threshold Optimization
    thresh.dt.list <- list()
    tsearch = seq(0.0001, 0.9999, by = 0.0001) # incremental steps to find best threshold value
    for (t in tsearch) {

      pred.class = ifelse(pred.prob.vec >= t, 1, 0) # set classes based on threshold, t

      # calculations to clean up Spec and Sens section, below
      a = sum(pred.class==1 & test.y.vec==1) # True Positive
      b = sum(pred.class==1 & test.y.vec==0) # False Positive
      c = sum(pred.class==0 & test.y.vec==1) # False Negative
      d = sum(pred.class==0 & test.y.vec==0) # True Negative
      sens = a / (a + c)
      spec = d / (b + d)
      tval <- sens + spec - 1

      #assign threshold and tval to list
      thresh.dt.list[[t*10000]] <- data.table::data.table(threshold = t, tss = tval)
    }

    thresh.dt <- do.call(rbind, thresh.dt.list)

    #select maximum sens + spec value and its threshold
    final.thresh <- thresh.dt[which.max(thresh.dt$tss),]

    # calculate classes based on optimized threshold
    pred.class.vec <- ifelse(pred.prob.vec >= final.thresh$threshold, 1, 0)

    # variable importance
    vi <- caret::varImp(RF_fit)

    # statistics
    a = sum(pred.class.vec==1 & test.y.vec==1) # True Positive
    b = sum(pred.class.vec==1 & test.y.vec==0) # False Positive
    c = sum(pred.class.vec==0 & test.y.vec==1) # False Negative
    d = sum(pred.class.vec==0 & test.y.vec==0) # True Negative

    roc.df <- WeightedROC::WeightedROC(pred.class.vec, test.y.vec)

    # an output list of results
    list(fit = RF_fit,
         pred.prob.vec= pred.prob.vec,
         test.X.mat = test.X.mat,
         test.y.vec = test.y.vec,
         is.train=is.train,
         importance=vi[1]$importance,
         feature=rownames(vi[1]$importance),
         TP = a,
         FP = b,
         FN = c,
         TN = d,
         TPR = a / (a + c),
         FPR = 1 - (d / (d + b)),
         TNR = d / (d + b),
         FNR = 1 - (a / (a + c)),
         sensitivity = a / (a + c), # same as TPR
         specificity = d / (b + d), # same as TNR
         tss = a/(a+c) + d/(b+d) - 1,
         precision = a / (a + b),
         f1 = (2 * (a / (a + b)) * (a / (a + c))) /
           ((a / (a + b)) + (a / (a + c))),
         matthews = ((a * d) - (b * c)) /
           sqrt((a + b + 1 - 1) * (a + c) * (d + b) * (d + c)), # need to add in +1 -1 to escape integer limit
         RMSE = sqrt(mean((pred.class.vec - test.y.vec)^2)),
         accuracy.percent = mean(pred.class.vec==test.y.vec)*100,
         auc = WeightedROC::WeightedAUC(roc.df),
         threshold = final.thresh$threshold,
         train.y.vec = train.y.vec)
  }),

  # algorithm 2
  earth=makeFun({

    train.df <- data.frame(
      label = factor(train.y.vec),
      train.X.mat,
      check.names=FALSE)

    fit <- earth::earth(
      label ~ .,
      data = train.df,
      trace = 3, #print progress.
      pmethod = "cv",
      nfold = 10,
      degree = 2 #flexibility in model fit (vs 1)
    )

    test.df <- data.frame(
      test.X.mat,
      check.names=FALSE)

    prop.zero <- colMeans(fit$dirs==0)

    #model results
    pred.prob.vec = predict(fit, test.df, type="response")

    #Threshold Optimization
    thresh.dt.list <- list()
    tsearch = seq(0.0001, 0.9999, by = 0.0001) # incremental steps to find best threshold value
    for (t in tsearch) {

      pred.class = ifelse(pred.prob.vec >= t, 1, 0) # set classes based on threshold

      # calculations to clean up Spec and Sens section, below
      a = sum(pred.class==1 & test.y.vec==1) # True Positive
      b = sum(pred.class==1 & test.y.vec==0) # False Positive
      c = sum(pred.class==0 & test.y.vec==1) # False Negative
      d = sum(pred.class==0 & test.y.vec==0) # True Negative
      sens = a / (a + c)
      spec = d / (b + d)
      tval <- sens + spec - 1

      #assign threshold and tval to list
      thresh.dt.list[[t*10000]] <- data.table::data.table(threshold = t, tss = tval)
    }

    thresh.dt <- do.call(rbind, thresh.dt.list)
    final.thresh <- thresh.dt[which.max(thresh.dt$tss)] #select maximum sens + spec value and its threshold

    pred.class.vec <- ifelse(pred.prob.vec >= final.thresh$threshold, 1, 0) # calculate classes based on optimized threshold


    a = sum(pred.class.vec==1 & test.y.vec==1) # True Positive
    b = sum(pred.class.vec==1 & test.y.vec==0) # False Positive
    c = sum(pred.class.vec==0 & test.y.vec==1) # False Negative
    d = sum(pred.class.vec==0 & test.y.vec==0) # True Negative

    roc.df <- WeightedROC::WeightedROC(pred.class.vec,test.y.vec)

    list(fit = fit,
         pred.prob.vec = pred.prob.vec,
         test.X.mat = test.X.mat,
         test.y.vec = test.y.vec,
         pred.class.vec = pred.class.vec,
         is.train = is.train,
         prop.zero = prop.zero,
         feature = names(prop.zero),
         TP = a,
         FP = b,
         FN = c,
         TN = d,
         TPR = a / (a + c),
         FPR = 1 - (d / (d + b)),
         TNR = d / (d + b),
         FNR = 1 - (a / (a + c)),
         sensitivity = a / (a + c),
         specificity = d / (b + d),
         tss = a/(a+c) + d/(b+d) - 1,
         precision = a / (a + b),
         f1 = (2 * (a / (a + b)) * (a / (a + c))) /
           ((a / (a + b)) + (a / (a + c))),
         matthews = ((a * d) - (b * c)) /
           sqrt((a + b + 1 - 1) * (a + c) * (d + b) * (d + c)), # need to add in +1 -1 to escape integer limit
         RMSE = sqrt(mean((pred.class.vec - test.y.vec)^2)),
         accuracy.percent = mean(pred.class.vec==test.y.vec)*100,
         auc = WeightedROC::WeightedAUC(roc.df),
         threshold = final.thresh$threshold,
         train.y.vec = train.y.vec)
  })
)


### SECTION 6 #################################
### Small interactive test run
# Run small instance to test for errors
## Interactively run each algorithm on small.instance to make sure it
## works here before calling addAlgorithm to indicate that it should
## be used with batchtools.
algo.list <- list()
funs.to.launch <- names(pred.fun.list)

# note: errors that occur are due to the reduced demo dataset given and
#       performing a regression on binary data
for(fun.name in funs.to.launch){
  pred.fun <- pred.fun.list[[fun.name]]
  small.result <- pred.fun(instance=small.instance)
  addAlgorithm(fun.name, reg=reg, fun=pred.fun)
  algo.list[[fun.name]] <- data.table()
}

### SECTION 7 #################################
### Prep and submit BT jobs
############
# create job table
## bind values to arguments of "cv" function...
## n jobs per algorithm where n = spp.csv(2) * n.fold (10) * n_algos (2)
addExperiments(
  list(cv=CJ(
    spp.csv=spp.csv.vec[1:2], #n_spp = 2
    n.folds=n.folds, # n_folds = 10
    test.fold=1:n.folds)),
  algo.list, # n_algos = 2
  reg=reg) # our registry

# a summary of the type of jobs to be created
summarizeExperiments(reg=reg)

# a more in depth view ofthe problem specifics
unwrap(getJobPars(reg=reg))

## in batchtools we can do array jobs if we assign the same chunk
## number to a bunch of different rows/jobs in the job table. Below we
## assign each job the chunk=1 so that there will be one call to
## sbatch and all of the rows become tasks of that one job. 
## (i.e. jobid = 1234 with 3 tasks, 1234_1, 1234_2,1234_3)
## Chunks should be increased with large number of jobs (e.g. >50,000).
(job.table <- getJobTable(reg=reg))
chunks <- data.table(job.table, chunk=1)

############
# Submit job tasks to Slurm
submitJobs(chunks, reg=reg, resources=list(
  walltime = 10,# minutes to request
  memory = 2000,# megabytes per cpu
  ncpus = 1, # single core here, non-parallel, this needs to be specified in algorithms as well (if allowed)
  chunks.as.arrayjobs=TRUE))# means to use job arrays (1_1,1_2...)instead of separate jobs (1,2...), for every chunk


# if you would like a live readout
while(1) {
  print(getStatus())
  print(getErrorMessages())
  Sys.sleep(15)
}
