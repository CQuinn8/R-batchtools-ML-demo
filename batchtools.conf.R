(slurm.tmpl <- normalizePath(
  "~/slurm-afterok.tmpl",
  mustWork=TRUE))
cluster.functions = makeClusterFunctionsSlurm(slurm.tmpl)
## Uncomment for running jobs interactively rather than using SLURM:
##cluster.functions = makeClusterFunctionsInteractive()
