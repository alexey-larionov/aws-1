This is a prototype for a pipeline to process whole exome sequencing data from fastq to annotated vcf. 
This is a work in progress yet including 
- a scaffold to parallelise calculations on AWS and 
- fastqc and alignment steps to test the scaffold 

Breif description:
- The "head-node" EC2 is launched interctively through AWS console, using the appropriate AMI
- The AMI contains tools and resources for the tasks (such as ref genome, FastQC, BWA etc)
- The AMI contains the scripts fot he pipeline
- The AMI contains a job-description template, which is used to indicate location of source data, location where the results should be saved etc.
- Then the pipeline is started to perform calculations as instructed in the job description file
- The pipeline assumes that SSH keys have been exchanged for connections betwen AWS and the sourse/results data servers
- Some other AWS-specific preparatios are also assumed (security groups, zones etc) 

Pipeline steps sofar:
- creates an EFS that will be used for shared data storage between different EC2 instances
- mounts it to the "head-node" EC2 
- copies source data from remorte NAS to EFS
- launches a separate "compute-node" EC2 instances for each sample (for the embarassingly parallel steps)
- mounts EFS to each of the "compute-node" EC2 instances
- performs QC and trimming of fasq files, runs alignment (BWA-mem + postalt, b38), does some BAM-files QC and processing (Picard metrics, sorting, removing PCR duplicates etc)

This repository is intended for the author's pesonal use. 
Version 03.17
