# Species Distribution Modeling using R batchtools
##### 13-April-2020 | EcoInformatics Seminar
### Goals for this seminar:
1. Introduction to xserver access to interactive Rstudio sessions on Monsoon HPC.
2. Using Rstudio on Monsoon.
3. Using R batchtools for machine learning. 

## 1. Access Monsoon and Rstudio
Log on to monsoon using an xserver. I use ([MobaXterm](https://mobaxterm.mobatek.net/)) on my Windows machine to access Monsoon and then interact with rstudio.
If you need help connecting to Monsoon see their [help page](https://in.nau.edu/hpc/overview/connecting-to-monsoon/). Also, for NAU's remote [VPN](https://in.nau.edu/its/remote-services/).
Once logged onto monsoon (e.g. `[user_id@wind ~ ]`) you can begin an rstudio session with this git repo code using the following:
1. Before doing any intensive or long term work we want to create an instance on a compute node and not work on the login node (@wind):
```
$ srun -t 1:00:00 --mem=4GB --cpus-per-task=1 --pty bash 
srun: job 29357400 queued and waiting for resources

```

2. cd into your desired directory/
`$ cd /scratch/<user_id>/ecoinf/`

3. load git module and clone GitHub repo
```
$ module load git
$ git clone https://github.com/CQuinn8/R-batchtools-ML-demo.git
Cloning into 'R-batchtools-ML-demo'...
remote: Enumerating objects: 65, done.
remote: Counting objects: 100% (65/65), done.
remote: Compressing objects: 100% (56/56), done.
remote: Total 65 (delta 27), reused 4 (delta 2), pack-reused 0
Unpacking objects: 100% (65/65), done.
$ cd R-batchtools-ML-demo/
```

4. Open Rstudio. Note: this may take a moment. Following '$ rstudio &' an interactive window will open with the Rstudio session. If you have .Rhistory or .Rdata files in the current wd this will also open. Batchtools may require these to be deleted before beginning new projects.
```
$ module avail rstudio
rstudio/0.98(default) rstudio/0.98-r3.5.0   rstudio/0.98-r3.5.2
$ module load rstudio/0.98-r3.5.2 # for the latest rstudio
$ rstudio &
```
Using `$ rstudio &` instead of `$ rstudio` allows you to continue using your current Monsoon session and run RStudio in the background.

## 2. Using Rstudio on Monsoon
1. Interact with Rstudio as you would on a local machine. First, we want to check where we are downloading packages to:
```
> .libPaths()
[1] "/home/cq73/ecoinf/R-batchtools-ML-demo/R/3.5"
[2] "/packages/R/3.5.2/bin"                                
[3] "/packages/R/3.5.2/lib64/R/library" 
```
Note that [1] should be 'pointing' to our current wd with "/R/X.X/" at the end of the path. This is a default R install directory for this wd and can be manually changed if desired. For now, we will make sure this exists and install Batchtool dependencies there.

Open "install.R" in our Rstudio session. There will be 6 packages to install. To manually install in the future you can use this option. 

However, for this demo, we will copy pre-installed packages as install.R takes ~10min. In our monsoon shell:
```
$ cp -r /scratch/cq73/ecoinf/R/ . 
```
All required packages should be in your wd under /R/3.5/. cd to this directory to verify we have R libraries copied there.


## 3a. Using R batchtools for machine learning: tree species distribution modeling 
Now that you have rstudio open, the git repo cloned, and batchtools dependencies properly installed in your directory we can walk through a species modeling example using two U.S. tree species (Table Maple Pine and Sugar Maple) and two machine learning algorithms (random forest and multiple adaptive regression splines [MARS]).

In our cloned git repo folder, open "batchtools_example.R". Make sure that RStudio was opened from monsoon while in the git repo folder.
#### Section 1:
1. Change userID to your NAU user ID
2. Run Section 1
#### Section 2:
Here we will set up the batchtools registry for our work.
1. Open "batchtools.conf.R". This file tells our work session that we will be working with Slurm as a job scheduler using "slurm_afterok.tmpl" as the batchtools template.
2. Open "slurm_afterok.tmpl". If you have used bash scripts with Slurm before you will recognize the format of this file. It serves as the bash script to initiate multiple jobs. More specifics on this later.
3. Run Section 2. You should see the following if your registry was successful:
```
Sourcing configuration file '/home/cq73/ecoinf/R-batchtools-ML-demo/batchtools.conf.R' ...
Created registry in '/home/cq73/ecoinf/R-batchtools-ML-demo/registry-demo' using cluster functions 'Slurm'
```
#### Section 3:
Now we prep data and skip to setup stages. Here we specify a reduced number of observations, this does not have to be done normally. You do need to specify the corresponding predictor variables though.
1. Run Section 3.

#### Section 4:
This section requires in depth exploration. For now we keep it simple and say that it sets up:
1. a small instance of our data to run interactively at the end of the script
2. a problem. This is what batchtools uses on each of our ML algorithms when submitted to monsoon (hence the "cv" or cross fold validation name)
3. Run Section 4.
#### Section 5: 
Feel free to explore the algorithms. They have grid searches for parameters and generation of predictive statistics based on the external cross fold validation test sets. 
#### Section 6:
Here, the small instance created earlier of two observations is run. Both algorithms are run to test for errors which we receive (and choose, here to ignore).
#### Section 7:
This section is what is unique and powerful using BT. A jobarray is created based on the number of functions (2, RF and MARS), number of subjects (2 trees), and the folds (10). The result is one job with 2*2*10 array items (40 jobs). In monsoon, when you use squeue you see the below for an array of 10:
```
             JOBID PARTITION     NAME     USER    STATE       TIME TIME_LIMI  NODES NODELIST(REASON)
        29504377_1       all job4e017     cq73  RUNNING       8:15     10:00      1 cn68
        29504377_2       all job4e017     cq73  RUNNING       8:15     10:00      1 cn66
        29504377_3       all job4e017     cq73  RUNNING       8:15     10:00      1 cn65
        29504377_4       all job4e017     cq73  RUNNING       8:15     10:00      1 cn64
        29504377_5       all job4e017     cq73  RUNNING       8:15     10:00      1 cn63
        29504377_6       all job4e017     cq73  RUNNING       8:15     10:00      1 cn63
        29504377_7       all job4e017     cq73  RUNNING       8:15     10:00      1 cn63
        29504377_8       all job4e017     cq73  RUNNING       8:15     10:00      1 cn63
        29504377_9       all job4e017     cq73  RUNNING       8:15     10:00      1 cn63
       29504377_10       all job4e017     cq73  RUNNING       8:15     10:00      1 cn63
```
Bash scripting can do the same thing manually passing the size of the array `#SBATCH --array=1-500` and when calling an rscript you can pass the job array ID (e.g 1,2,3...500) as a wildcard to the script: `Rscript /projects/species_model.R $SLURM_ARRAY_TASK_ID`

In the BT jobtable (lives in the registry), errors and notes are recorded so that we know if any job array IDs have failed and what reason they failed. This bcomes a useful aspect with large arrays (e.g. >10,000).


## 3b. Viewing batchtools resutls
Open "quick_result_example.R" and run through script (replace userID again). THis script simply shows how to access our results that are queried through the job table. Below is the output result from one of the job arrays run from above:

```
> algo.result <- loadResult(test.set.info)
> algo.result$TP
[1] 14
> algo.result$FP
[1] 133
> algo.result$TN
[1] 2105
> algo.result$FN
[1] 3
> algo.result$auc
[1] 0.8820507
> algo.result$tss
[1] 0.7641014
```
Further results can be visualized here: 

## Warnings and things to know using RStudio on Monsoon with an xserver:
1. Patience is key with xservers! Especially on a VPN. 
2. Sometimes selcted code will be replaced with a "." Just hit "ctl+z" to fix this.
3. Rstudio r0.98-3.4.2 does not support "ctr+ENTER" to run a chunk of code by default.
4. For a more extensive implementation on Batchtools see https://tdhock.github.io/blog/2020/monsoon-batchtools/
