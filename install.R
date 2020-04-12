# Specify library location to change where libraries are downloaded and loaded.
userID = "" # e.g. abc123
ll = paste0("/scratch/", userID, "/R/3.5/")
 
install.packages(c("rlang","batchtools","namedCapture", 
                   "caret", "earth", 
                   "WeightedROC"), 
                 lib = ll)

# install.packages("batchtools", lib.loc = ll)
