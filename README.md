This is a prototype for a pipeline to process whole exome sequencing data from fastq to annotated vcf.   
This is a work in progress  

Currently it includes  
- a scaffold to parallelise calculations on AWS and   
- fastqc and alignment steps to test the scaffold   

Outlook:  
- The "head-node" EC2 is launched interctively through AWS console, using the appropriate AMI  
- The AMI contains tools and resources for the tasks (such as ref genome, FastQC, BWA etc)  
- The AMI contains the pipeline scripts  
- The AMI contains a job-description template, which is used to indicate location of source data, location where the results should be saved etc.  
- The pipeline is started using launcher script with the job description file  
- The pipeline assumes that SSH keys have been exchanged for connections betwen AWS and the sourse/results data servers  
- Some other AWS-specific preparatios are also assumed (pre-existing security groups, aws setting for zones etc)   

Current pipeline steps:  
- Creates an EFS that will be used for shared data storage between different EC2 instances  
- Mounts the shared EFS to the "head-node" EC2  
- Copies source data from the source to the shared EFS (assuming ssh keys exchanged)  
- Launches a separate "compute-node" EC2 instance for each sample (for the embarassingly parallel processing):  
  - Mounts the shared EFS to each of the "compute-node" EC2 instances  
  - Performs QC and trimming of fasq files, runs alignment (BWA-mem + postalt, b38)  
  - Performs BAM QC and processing (Flagstat, Picard metrics, sorting, fixing, removing PCR duplicates etc)  
  - (Unmounts EFS?) and terminates the node  
- After all samples are completed, makes summary plots for QC metrics  
- Copies results to required remote destination (assuming ssh keys exchanged)  
- 

While running, the "head node" EC2 may be used to access "compute" nodes and monitor the progress.  
E-mail notifications are sent during the pipeline steps

To do before holidays:  
- Review the scripts to remove unnecessary bits  
- Update versions of tools and resources  
- Add toy data and example script for each tool  
- check aws and ssh settings on AMI and sourse/destination NASs  
- Explore setting a new user with minimal comfortable non-admin IAM rights  
  
To consider later:
- Switch from BAM to CRAM ?  
- Switch from rsynk to aspera ?  
- Add web-interface to help preparing the job description ?   
- Add web-interface to set and check ssh-connections ?  
  
This repository is intended for the author's pesonal use.   
Version 08.17  
