# Species Distribution Modeling using R batchtools
##### 13-April-2020 | EcoInformatics Seminar
### Goals for this seminar:
1. Introduction to xserver access to interactive Rstudio sessions on Monsoon HPC.
2. Using Rstudio on Monsoon.
3. Using R batchtools for machine learning 

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

3. load git and clone repo
```
$ module load git
$ git clone https://github.com/CQuinn8/R-batchtools-ML-demo.git
$ cd R-batchtools-ML-demo/
```

4. Open Rstudio 
```
$ module avail rstudio
rstudio/0.98(default) rstudio/0.98-r3.5.0   rstudio/0.98-r3.5.2
$ module load rstudio/0.98-r3.5.2 # for the latest rstudio
$ rstudio
```

5. Interact with Rstudio as you would on a local machine...

## Species distribution modeling using batchtools 
1. Now that you have rstudio open, the git repo cloned, and batchtools properly installed on your directory we can walk through a species modeling example using two U.S. tree species (sugar maple and red maple) and two machine learning algorithms (random forest and multiple adaptive regression splines/MARS).

