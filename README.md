# R-batchtools-ML-demo
An implementation of R's batchtools to demonstrate large slurm array scheduling of simple machine learning algorithms. 

# Before you run anything:
1) Your directory should be downloaded/located on Monsoon. In your directory you should have:
    1) an R script that uses batchtools
    2) batchtools.conf.R
    3) slurm-template.tmpl
    4) data/ (with 2 csvs)
    5) install.R

2) Prepare your directory with proper packages by running install.R. 

3) In batchtools_example.R you will want to change lines 17 & 31 to relative pathways in your monsoon account.

4) at the command line, cd to your directory and run the below two lines to initiate the scheduling:  
      module load R  
      Rscript --vanilla batchtools_example.R

To check how the job is doing, record the jobid or view the logs created in your registry directory. Following the completion of the job, the list created for model results will live in the results directory of the registry where you can use Batchtools to then read in the job results or interpret the .rds files with your favorite method (future script coming!).
