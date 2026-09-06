# plasmid-nf
Small pipeline for the assembly & characterization of plasmids from ONT-seq reads. 
This pipeline is version from my personal unix-profile, so there is various conda-env execution (with all installed dependencies) is used. You can replace this logic with docker-containers execution for cross-platform usability. Probably, it will be also done oneday for this repo.  

## INSTALLATION

You have to have conda (miniconda) installation as well as git, nextflow and python installation. 

To copy pipeline you can use:
```
git clone https://github.com/AIKozyreva/plasmid-nf.git
```
## USAGE

To use this pipeline you have to activate your conda-environment with installed nextflow, python. In your system you have to have installed environment with all nedded dependencies. The name of the conda-env, where script will look for the executables is mentioned in the beginning of the "script" section in the almost each module in ./modules/*.nf

By the time of the first pipeline running, you had already rewritten modules for your system and configured it correctly. Then begin:
```
cd plasmid-nf

nextflow run main.nf --worklist /path/to/your/worklist/yymmdd_worklist.csv --threads 8 --outdir /path/to/your/outdir/yymmdd_pipeout --assembler autocycler 
```
Every usual for nextflow pipelines options are available, for example "--resume" and "--force". By default, output will be saved in ./results_def folder in the actual working directory.
