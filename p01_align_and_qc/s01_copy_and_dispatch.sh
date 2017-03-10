#!/bin/bash

# s01_copy_and_dispatch.sh
# Started: Alexey Larionov, 25Nov2016
# Last updated: Alexey Larionov, 26Feb2016

# Tasks:
# - create efs
# - mount efs on the head-node instance
# - copy source data to efs
# - for each sample: 
#    start new ec2 instance 
#    mount efs and start alignment pipeline on the new ec2 instance 

# The head instance is kept for all pipeline duration: 
# - to provide opportunity for progress-checks and debuging
# - to run summarise-and-save step after all samples are completed

# Prerequests:
# - configured security groups on aws
# - configured aws cli
# - assumes connectuion as "ec2-user"
# - ssh keys exchanged bwtween ec2-ami and nas
# - pem key on the AMIs (chmod 400)
# - avaialbility of accessory functions etc

# References:
# http://docs.aws.amazon.com/efs/latest/ug/wt1-getting-started.html
# http://docs.aws.amazon.com/efs/latest/ug/wt1-create-ec2-resources.html
# http://docs.aws.amazon.com/efs/latest/ug/wt1-create-efs-resources.html 
# http://docs.aws.amazon.com/efs/latest/ug/wt1-test.html 

# Note:
# In Dec2016 efs was supported in Europe by the Ireland region (eu-west-1) only
# This is why I used Ireland (eu-west-1) instead of London (eu-west-2).  
# Accordingly, the default aws-cli credentials on AMI also set to Ireland (eu-west-1)

# could it be done as a wdl task ?

# ----------------------------------------------------------------- #
#                         Initial settings                          #
# ----------------------------------------------------------------- #

# Stop at errors
set -e

# Read arguments
job_file="${1}"
ec2_pipeline_log="${2}"
ec2_logs_folder="${3}"
scripts_folder="${4}"

# Progress report
echo "----------------- Create and mount efs ---------------" >> "${ec2_pipeline_log}"
echo "" >> "${ec2_pipeline_log}"

# Read job's settings
source "${scripts_folder}/g01_read_config.sh" "${job_file}"

# Get current ami id
this_ec2_ami_id="$(ec2-metadata -a)"
this_ec2_ami_id="${this_ec2_ami_id/ami-id: /}"

# Get current ec2 ip
this_ec2_local_ip="$(ec2-metadata -o)"
this_ec2_local_ip="${this_ec2_local_ip/local-ipv4: /}"

# Set initial working folder and make folder to mount efs on head node
cd "${ec2_project_folder}"
mkdir -p "${efs_base_folder}"

# ----------------------------------------------------------------- #
#                      Create shared file system                    #
# ----------------------------------------------------------------- #
# Notes: 
# There will be an error if an efs with "${efs_token}" already exists

# Load function for creating efs
source "${scripts_folder}/k02_create_efs.sh"

# Create efs
efs_id=$(create_efs \
  "${efs_token}" \
  "${ec2_logs_folder}" \
  "${ec2_pipeline_log}" \
  "${region}" \
  "${job_file}")

# ----------------------------------------------------------------- #
#                     Make a mount target for efs                   #
# ----------------------------------------------------------------- #
# Notes: 
# The subnet-id and security-group were taken from the account's WEB interface.
# Later a mount point may be created for each subnet in the region to allow 
# automatic allocation of ec2 instances to availability zones.

# Load function for creating efs mount target
source "${scripts_folder}/k03_create_efs_mount_target.sh"

# Create efs mount target
efs_mount_tgt_ip=$(create_efs_mount_target \
  "${efs_id}" \
  "${ec2_logs_folder}" \
  "${ec2_pipeline_log}" \
  "${subnet_id}" \
  "${mt_security_group_id}" \
  "${region}" \
  "${job_file}")

# ------------------------------------------------------------------ #
#       Mount shared efs file system to the head ec2 instance        #
# ------------------------------------------------------------------ #
# Notes: 
# http://docs.aws.amazon.com/efs/latest/ug/mounting-fs-mount-cmd-general.html

# Make script (assuming that empty ~/efs folder exists)
# sudo is necessary for the "--options" option
sudo mount \
  -t nfs4 \
  -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 \
  "${efs_mount_tgt_ip}":/   "${efs_base_folder}"

# Executing the previous command as sudo assigned ownership to root 
# To prevent problems with accessing writing to to efs, the ownership should be changed to ec2-user 
sudo chown -R ec2-user "${efs_base_folder}"
sudo chgrp -R ec2-user "${efs_base_folder}"

# Progress report
echo "Mounted shared efs file system on the start head-node: $(date +%d%b%Y_%H:%M:%S)" >> "${ec2_pipeline_log}"
echo "" >> "${ec2_pipeline_log}"

# ------------------------------------------------------------------ #
#              Configure shared files and folders on efs             #
# ------------------------------------------------------------------ #

# Move project folder to the newly created and mounted efs
mv "${ec2_project_folder}" "${project_folder}"

# Set working folder to efs
cd "${project_folder}"

# Copy job description file to efs,
# use the efs-located job file from now on
cp "${job_file}" "${project_folder}/"
job_file_name=$(basename "${job_file}")
job_file="${project_folder}/${job_file_name}"

# Switch logging to efs
pipeline_log="${logs_folder}/a00_pipeline_${project}_${library}_${lane}.log"

# Make folders on efs
mkdir -p "${raw_fastq_folder}"
mkdir -p "${raw_fastqc_folder}"
mkdir -p "${trimmed_fastq_folder}"
mkdir -p "${trimmed_fastqc_folder}"

mkdir -p "${bam_folder}"
mkdir -p "${hla_folder}"

mkdir -p "${flagstat_folder}"
mkdir -p "${picard_mkdup_folder}"
mkdir -p "${picard_inserts_folder}"
mkdir -p "${picard_alignment_folder}"
mkdir -p "${picard_hybridisation_folder}"
mkdir -p "${picard_summary_folder}"
mkdir -p "${qualimap_results_folder}"
mkdir -p "${samstat_results_folder}"

# Progress report
echo "Made folders tree on efs" >> "${pipeline_log}"

# Start list of bams out
echo -e "samples\tbam_files" > "${bam_samples_file_out}"

echo "Made file for recording completed bam samples" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# ---------------------------------------------------------------------------- #
#                        Copy source data from nas to efs                      #
# ---------------------------------------------------------------------------- #
# So far it only supports pe data; support for se data may be added later 

# Progress report
echo "------------------- Copy source data -----------------" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"
echo "Started: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# Copy samples list
samples_file_in="$(basename ${fastq_samples_file_in})"
rsync -ahe ssh "${nas}:${src_nas_folder}/${samples_file_in}" "${raw_fastq_folder}/" &>> "${pipeline_log}"

# For each sample in the samples list
while read sample fastq1 fastq2 md5
do
  
  # Skip the header line
  if [ "${sample}" == "sample" ]
  then
    continue
  fi
  
  # Copy fastq1
  rsync -ahe ssh "${nas}:${src_nas_folder}/${fastq1}" "${raw_fastq_folder}/" &>> "${pipeline_log}"

  # Copy fastq2
  rsync -ahe ssh "${nas}:${src_nas_folder}/${fastq2}" "${raw_fastq_folder}/" &>> "${pipeline_log}"

  # Copy md5
  rsync -ahe ssh "${nas}:${src_nas_folder}/${md5}" "${raw_fastq_folder}/" &>> "${pipeline_log}"

  # Progress report
  echo "  copied sample ${sample}: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
  
done < "${fastq_samples_file_in}"

# Progress report
echo "" >> "${pipeline_log}"
echo "Completed copying all samples: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# Progress report by e-mail
echo -e \
"wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
"Completed copying data to ${efs_token} file system at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n" \
 | mail -s "Completed copying data for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}"

# ---------------------------------------------------------------------------- #
#  Dispatch samples to execute pipeline in parallel on separate ec2 instances  #
# ---------------------------------------------------------------------------- #
# could it be done as a wdl scatter?

# !!! Do not use "while read .." loop with ssh inside it !!!
# It seems that ssh breaks the "while read .." loop (changes pointer within the loop file?)
# http://stackoverflow.com/questions/9393038/ssh-breaks-out-of-while-loop-in-bash
# http://unix.stackexchange.com/questions/107800/using-while-loop-to-ssh-to-multiple-servers
# Also "while read .." is pernicaty about empty line at end of the file etc

# Progress report
echo "-------- Dispatch samples to individual ec2-s --------" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# Get list of samples from fastq-files-list
samples=$(awk 'NR>1 {print $1}' "${fastq_samples_file_in}")

# Load function for creating ec2 instance
source "${scripts_folder}/k01_create_ec2_instance.sh"

# For each sample
for sample in ${samples}
do

  # Progress report
  echo "----- ${sample} -----" >> "${pipeline_log}"
  echo "" >> "${pipeline_log}"
  
  # --------------------- Start a new ec2 instance --------------------- #
  
  new_ec2_local_ip=$(create_ec2_instance \
    "${sample}" \
    "${logs_folder}" \
    "${pipeline_log}" \
    "${this_ec2_ami_id}" \
    "${align_qc_instance_type}" \
    "${key_name}" \
    "${region}" \
    "${subnet_id}" \
    "${ec2_security_group_id}" \
    "${job_file}")
  
  # --- Mount shared efs file system and start alignment on the new ec2 instance --- #

  sample_alignment_log="${logs_folder}/${sample}_alignment_and_qc.log" # to log sample alignment
  efs_mount_tgt_creation_log="${logs_folder}/efs_mount_tgt_creation.log" # had been made earlier (during efs creation)
  efs_mount_tgt_ip=$(jq -r '.IpAddress' < "${efs_mount_tgt_creation_log}")
  
  script='
  mkdir -p '"${efs_base_folder}"'
  sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 '"${efs_mount_tgt_ip}"':/ '"${efs_base_folder}"'
  '"${scripts_folder}"'/s02a_start_align_and_qc.sh '"${sample}"' '"${scripts_folder}"' '"${job_file}"' '"${pipeline_log}"' '"${this_ec2_local_ip}"' &> '"${sample_alignment_log}"

  # Execute script on the sample's ec2 instance via ssh
  # -o StrictHostKeyChecking=no to avoid the dialogue about acceptance of the host signature
  # -o UserKnownHostsFile=/dev/null to avoid adding each new ec2 instance to the known hosts file 
  # -o LogLevel=error to suppress the scary message that the host was "permanently added .." 
  ssh \
    -i "${key_file}" \
    -o "LogLevel=error" \
    -o "StrictHostKeyChecking=no" \
    -o "UserKnownHostsFile=/dev/null" \
    "ec2-user@${new_ec2_local_ip}" "${script}" & # do not wait for completion!
  
  disown $! # Disown the started process to avoid potential issues when terminating the head instance?
  
  # Progress report
  echo "  Mounted efs and started alignment" >> "${pipeline_log}"
  echo "" >> "${pipeline_log}"

done # next sample

# Progress report
echo "Submitted all samples: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# Progress report by e-mail
echo -e \
"wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
"Submitted all samples at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n"\
 | mail -s "Submitted all samples for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}"

# Do NOT terminate the head instance here: 
# After launching the samples it stays idle during all the pipeline run 
# providing and opportunity for progress checks and debugging. 
# When processing of all the samples is completed, the head node is used for the 
# final summarise-and-save step.  
