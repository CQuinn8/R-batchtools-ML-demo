# R-batchtools-ML-demo
An implementation of R's batchtools to demonstrate large slurm array scheduling of simple machine learning algorithms.

# Before you run anything:
- prepare your local directory by installing:
  1. batchtools
  2. namedCapture
  3. earth
  4. caret
  5. WeightedROC
  6. rlang 
  
- in your directory you should have:
  1. an R script that uses batchtools
  2. batchtools.conf.R
  3. slurm-template.tmpl
  4. data/ (with 2 csvs)
