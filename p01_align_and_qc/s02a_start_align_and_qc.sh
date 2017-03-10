#!/bin/bash

# s02_align_and_qc.sh
# Started: Alexey Larionov, Nov2016
# Last updated: Alexey Larionov, 25Feb2017

# Tasks:
# - run alignment and qc pipeline for one sample
# - check whether all samples completed 
# - start summrise and save script on a new ec2 instance 
#   when all samples are completed  
# -Stop this ec2 instance at the end

# -------------------- Start-up and config --------------------- #

# Stop at errors
set -e

# Read arguments
sample="${1}"
scripts_folder="${2}"
job_file="${3}"
pipeline_log="${4}"
head_ec2_local_ip="${5}"

# Read job's settings
source "${scripts_folder}/g01_read_config.sh" "${job_file}"

# Set working folder
cd "${project_folder}"

# Get current ami id
this_ec2_ami_id="$(ec2-metadata -a)"
this_ec2_ami_id="${this_ec2_ami_id/ami-id: /}"

# Get current instance IP
this_ec2_ip="$(ec2-metadata -v)"
this_ec2_ip="${this_ec2_ip/public-ipv4: /}"

# ----------------------- Start alignment ---------------------- #
# Done for pe data only; yet to add se data

# Progress report by e-mail
echo -e \
"wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
"Started aligning ${sample} on ${this_ec2_ip} at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n"\
 | mail -s "Started ${sample} for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}"

# pe data 
if [ "${data_type}" == "pe" ]
then 
  "${scripts_folder}/s02b_align_and_qc_pe.sh" \
         "${sample}" \
         "${job_file}" \
         "${scripts_folder}" \
         "${pipeline_log}" \
         "${data_type}"
fi

# --------------- After the alignment is complete -------------- #

# Update list of completed samples
echo -e "${sample}\tnot_yet_done" >> "${bam_samples_file_out}"

# Progress report to sample log
echo "Completed aligning ${sample}: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# Progress report to main log
echo "Completed aligning ${sample}: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# Progress report by e-mail
echo -e \
"wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
"Completed aligning ${sample} on ${this_ec2_ip} at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n"\
 | mail -s "Completed ${sample} for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}"

# -------- Check whether all samples have been completed ------- #

# Get list of fastq_samples
fastq_samples=$(awk 'NR>1{print $1}' "${fastq_samples_file_in}")

# Set flag as if all samples were completed
all_completed="yes"

# For each sample
for fastq_sample in $fastq_samples
do

  # Look for this sample in the file of completed samples
  sample_check=$(awk -v var="${fastq_sample}" '$0 ~ var' "${bam_samples_file_out}")
  
  # Update flag if no completion record has been found
  if [ -z "${sample_check}" ]
  then
    all_completed="no"
    break
  fi
  
done

# Progress report to sample log
echo "Completed all samples: ${all_completed}" 
echo ""

# --- Re-order bam_samples_file_out and start summarise-save --- #

# If all samples have been completed
if [ "${all_completed}" == "yes" ]
then
  
  # Report to pipeline log
  echo "Completed all samples" >> "${pipeline_log}"
  echo "" >> "${pipeline_log}"
  
  # Reorder bam samples file according to the initial order of fastq samples
  bam_samples_tmp=$(mktemp "${bam_samples_file_out}.tmp.XXXX")
  cp -f "${bam_samples_file_out}" "${bam_samples_tmp}"
  
  header=$(head -n 1 "${bam_samples_tmp}")
  echo "${header}" > "${bam_samples_file_out}"
  
  for sample in $fastq_samples
  do
    cur_line=$(awk -v smp="${sample}" '$1==smp {print}' "${bam_samples_tmp}")
    echo "${cur_line}" >> "${bam_samples_file_out}"
  done
  
  rm -f "${bam_samples_tmp}"

  # Report to pipeline log
  echo "Reordered bam_samples_file_out" >> "${pipeline_log}"
  echo "" >> "${pipeline_log}"

  # Report to sample log
  echo "Reordered bam_samples_file_out"

  # ----- Start summarise-and-save on the head ec2 instance ---- #

  echo "------------------ Summarise and save ----------------" >> "${pipeline_log}"
  echo "" >> "${pipeline_log}"
  
  summarise_save_log="${logs_folder}/summarise_and_save.log"
  
  # TODO: Make different scripts for PE and SE !!!
  script="${scripts_folder}/s03_summarise_and_save.sh ${scripts_folder} ${job_file} ${pipeline_log} ${summarise_save_log}"
  
  # Execute script on the head ec2 instance via ssh
  ssh \
    -i "${key_file}" \
    -o "LogLevel=error" \
    -o "StrictHostKeyChecking=no" \
    -o "UserKnownHostsFile=/dev/null" \
    "ec2-user@${head_ec2_local_ip}" "${script}" & # do not wait for completion!
  
  disown $! # Disown the started process to avoid potential issues when terminating the sample's ec2 instance
  
  # Report to sample log
  echo "Submitted job to summarise and save results"
  echo ""

  # Report to the main log
  echo "Submitted job to summarise and save results" >> "${pipeline_log}"
  echo "" >> "${pipeline_log}"

fi

# ----------------- Terminate this ec2 instance ---------------- #
# (unmounting efs is not essential here)

# Progress report to sample log
echo "Terminating ${sample} ec2 instance"
echo ""

# Unmount efs and terminate ec2 instance
sudo umount -l "${efs_base_folder}"
this_ec2_id="$(ec2-metadata -i)"
this_ec2_id="${this_ec2_id/instance-id: /}"
aws ec2 terminate-instances --instance-ids "${this_ec2_id}" > /dev/null 
    # >dev/null is to suppress returning json output to log
