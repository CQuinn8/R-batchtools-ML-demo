# Title: batchtools scheduling package used to help with large Monsoon arrays
# Author: Colin Quinn (cq73@nau.edu; modified by code provided by Toby Hocking)
# School of Informatics, Computing, and Cyber Systems, NAU
# Created: 6-January-2020

# best to download the versions of packages you need to a location
.libPaths()
library(rlang)
library(batchtools) # creates schedule enviro
library(namedCapture)
library(caret) # multiple ML algos
library(earth) # specific ML algo
library(WeightedROC)

############
# Working directory space on monsoon
wd = ""

# monsoon specs
# CPUs = 1
# options(future.availableCores.methods = "mc.cores")
# options(mc.cores = 1)

#############
#Batch tools ML Algo implementation

# number of bootstraps (note, you can skip this and specify in your ML code)
n.folds <- 10

# registry, this must be a new pathway that is not yet created on monsoon (i.e. "/scratch/user/registry-1")
reg.dir <- ""

# Before creating your registry make sure to define cluster functions with this template
if(FALSE){ #put this in your ~/.batchtools.conf.R:
  cluster.functions = makeClusterFunctionsSlurm(paste0(wd,"slurm-template.tmpl"))
}

# Creating your registry (should see: > Sourcing configuration file '')
reg <- if(file.exists(reg.dir)){
  loadRegistry(reg.dir)
}else{
  makeExperimentRegistry(reg.dir)
}

############
# Data
# Define data sets/files here
spp.csv.vec <- normalizePath(Sys.glob("data/*.csv"))

# Initializes all the variables in the next function wth a single file,
#  for interactive testing.
spp.csv <- spp.csv.vec[1]
spp <- fread(spp.csv[1])[c(1:1000),] # reducing the size of example csvs to demo
all.X.mat <- as.matrix(spp[, c(6:20)]) # all predictor variables in a matrix
all.y.vec <- spp$PRES # response variable as a vector


############
# Setting up modeling and batchtools environment
# create training/testing splits for 10 model implementations
some.i <- as.integer(sapply(c(0,1), function(y)which(all.y.vec==y)[1:n.folds]))

# create splits in small.instance for interactive testing
small.instance <- list(
    train.X.mat=all.X.mat[some.i,],
    train.y.vec=all.y.vec[some.i],
    #train.weight.vec=rep(1, length(some.i)),

    # select a highly reduced number of observations
    #  note: here, data are binary and need differing responses to work (obs 28 and 29)
    test.X.mat=all.X.mat[28:29,],
    is.train="foo",
    test.y.vec = all.y.vec[28:29])

# at the bottom of this chunk, training and testing data are created for all species
addProblem("cv", reg=reg, fun=function(job, data, spp.csv, test.fold, n.folds, weight.name, ...){
  species.id <- namedCapture::str_match_variable(
    spp.csv,
    "_",
    id="[0-9]+")
  spp <- data.table::fread(spp.csv)[c(1:1000),] # reducing size of csv
  all.X.mat <- as.matrix(spp[, c(6:20)]) # make sure this matches your variables
  all.y.vec <- spp$PRES

  set.seed(1)
  all.fold.vec <- sample(rep(1:n.folds, l=nrow(all.X.mat)))
  is.train <- all.fold.vec != test.fold
  # here you can input each species or unit of interest in the vector
  species.name.vec <- c(
    "105"="jack pine",
    "107"="sand pine"
    )
  train.y.vec <- all.y.vec[is.train]
  response.tab <- table(train.y.vec)
  other.tab <- response.tab #need to assign weights to other class.
  names(other.tab) <- rev(names(response.tab))
  response.dec <- sort(response.tab, decreasing=TRUE)
  major.prob <- as.integer(names(response.dec)[1])
#   large.weight.vec <- as.numeric(other.tab[paste(train.y.vec)])
#   weight.list <- list(
#     balanced=large.weight.vec,
#     one=rep(1, length(large.weight.vec)))
  some.i <- as.integer(
    sapply(c(0,1), function(y)which(train.y.vec==y)[1:n.folds]))
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

makeFun <- function(expr){
  e <- substitute(expr)
  function(instance, ...){
    eval(e, instance)
  }
}

# specifies the functions to carry ou on the data created in the addProblem above
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

############
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

############
# create job table
## bind values to arguments of "cv" function...
## n jobs per algorithm where n = spp.csv(2) * n.fold (10)
addExperiments(
  list(cv=CJ(
    spp.csv=spp.csv.vec[1:2], # change this to run on the number of units of interest, here species = 2
    n.folds=n.folds,
    test.fold=1:n.folds)),
  algo.list,
  reg=reg)

# a summary of the type of jobs to be created
summarizeExperiments(reg=reg)

# a more in depth view ofthe problem specifics
unwrap(getJobPars(reg=reg))

## in batchtools we can do array jobs if we assign the same chunk
## number to a bunch of different rows/jobs in the job table. Below we
## assign each job the chunk=1 so that there will be one call to
## sbatch and all of the rows become tasks of that one job.
## (i.e. jobid = 1234 with 3 tasks, 1234_1, 1234_2,1234_3)
(job.table <- getJobTable(reg=reg))
chunks <- data.table(job.table, chunk=1)

############
# Submit job tasks to Slurm
submitJobs(chunks, reg=reg, resources=list(
  walltime = 60,# minutes to request
  memory = 2000,# megabytes per cpu
  ncpus = 1, # single core here, non-parallel
  chunks.as.arrayjobs=TRUE))# means to use job arrays instead of separate jobs, for every chunk


# if you would like a live readout
# while(1) {
#   print(getStatus())
#   print(getErrorMessages())
#   Sys.sleep(45)
# }

