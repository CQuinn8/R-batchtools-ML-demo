# R-batchtools-ML-demo
An implementation of R's batchtools to demonstrate large slurm array scheduling of simple machine learning algorithms. 

# Before you run anything:
Your directory should be located on Monsoon. In your directory you should have:
  1) an R script that uses batchtools
  2) batchtools.conf.R
  3) slurm-template.tmpl
  4) data/ (with 2 csvs)

Prepare your directory by installing:
  1. batchtools
  2. namedCapture
  3. earth
  4. caret
  5. WeightedROC
  6. rlang 

Following the above setup:
1) In batchtools_example.R: you will want to change lines 17 & 31 to relevant pathways on your device.
2) at the command line, cd to your directory and run the below two lines to initiate the scheduling:
     module load R
     Rscript --vanilla batchtools_example.R
