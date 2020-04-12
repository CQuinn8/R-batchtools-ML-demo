# Specify library location to change where libraries are downloaded and loaded.
# If this is your first R session in this directory, "/R/" will not exist.
.libPaths() # make sure [1] is your wd
install.packages(c("rlang","batchtools","namedCapture", # general packages
                   "caret", "earth", "ranger", "e1071", # ML packages
                   "WeightedROC")) # error assessment


# if you have /R/ in your wd use the below
#userID = "" # e.g. abc123
#ll = paste0("/scratch/", userID, "/R/3.5/")
#
#install.packages(c("rlang","batchtools","namedCapture", 
#                   "caret", "earth", "ranger", "e1071",
#                   "WeightedROC"), 
#                 lib = ll)
