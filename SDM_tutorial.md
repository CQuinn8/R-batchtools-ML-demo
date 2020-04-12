# Species Distribution Modeling using R batchtools
##### 13-April-2020 | EcoInformatics Seminar
### Goals for this seminar:
1. Introduction to xserver access to interactive Rstudio sessions on Monsoon HPC.
2. Using Rstudio on Monsoon.
3. Using R batchtools for machine learning. 

## Access Monsoon and Rstudio
Log on to monsoon using an xserver. I use ([MobaXterm](https://mobaxterm.mobatek.net/)) on my Windows machine to access Monsoon and then interact with rstudio.
If you need help connecting to Monsoon see their [help page](https://in.nau.edu/hpc/overview/connecting-to-monsoon/). Also, for NAU's remote [VPN](https://in.nau.edu/its/remote-services/).
Once logged onto monsoon (e.g. `[user_id@wind ~ ]`) you can begin an rstudio session with this git repo code using the following:
1. Before doing any intensive or long term work we want to create an instance on a compute node and not work on the login node (@wind):
```
$ srun -t 2:00:00 --mem=4GB --cpus-per-task=1 --pty bash 
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

5. Interact with Rstudio as you would on a local machine. First, we want to check where we are downloading packages to:
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
All required packages should be in your wd under ~./R/3.5/. cd to this directory to verify we have R libraries copied there.


## Species distribution modeling using batchtools 
1. Now that you have rstudio open, the git repo cloned, and batchtools dependencies properly installed in your directory we can walk through a species modeling example using two U.S. tree species (sugar maple and table mountain pine) and two machine learning algorithms (random forest and multiple adaptive regression splines [MARS]).

