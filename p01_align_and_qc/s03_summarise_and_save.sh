#!/bin/bash

# s03_summarise_and_save.sh
# Started: Alexey Larionov, Nov2016
# Last updated: Alexey Larionov, 26Feb2017

# Tasks:
# - summarise and save results from samples alignment
# - Unmount and stop efs and storp this ec2 instance at the end

# -------------------- Start-up and config --------------------- #

# Stop at errors
set -e

# Read arguments
scripts_folder="${1}"
job_file="${2}"
pipeline_log="${3}"
summarise_save_log="${4}"

# Read job's settings
source "${scripts_folder}/g01_read_config.sh" "${job_file}"

# Set working folder
cd "${project_folder}"

# Get current ec2 instance IP  (this is the head instance)
this_ec2_ip="$(ec2-metadata -v)"
this_ec2_ip="${this_ec2_ip/public-ipv4: /}"

# Progress report by e-mail
echo -e \
"wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
"Started summarise and save on ${this_ec2_ip} at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n"\
 | mail -s "Started summarise and save for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}"

# -------------------------------------------------------------- #
#                        Summarise results                       #
# -------------------------------------------------------------- #

# Progress report to summarise-save log
echo "Started summarising results: $(date +%d%b%Y_%H:%M:%S)" >> "${summarise_save_log}"
echo "" >> "${summarise_save_log}"

# Progress report to the main log
echo "Started summarising results: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# --------------------- Summarise raw fastqc ------------------- #

# Prepare header for the fastqc summary file
a_sample=$(awk 'NR==2 {print $1}' "${fastq_samples_file_in}")
a_fastq_file=$(awk 'NR==2 {print $2}' "${fastq_samples_file_in}")
a_fastqc_folder="${a_fastq_file%.fastq.gz}_fastqc"
a_fastqc_summary_file="${raw_fastqc_folder}/${a_fastqc_folder}/summary.txt"
fastqc_summary_fields=$(awk 'BEGIN { FS="\t" } ; {print $2}' "${a_fastqc_summary_file}")
fastqc_summary_header=${fastqc_summary_fields// /_}
fastqc_summary_header=${fastqc_summary_header//$'\n'/'\t'} 
# note $ before '\n'
# http://stackoverflow.com/questions/7129047/new-line-in-bash-parameter-substitution-rev-n
fastqc_summary_header="Sample_Read\t${fastqc_summary_header}"
echo -e "${fastqc_summary_header}" > "${raw_fastqc_folder}/raw_fastqc_summary.txt"

# Collect data
while read sample fastq1 fastq2 md5
do

  # Skip the header line
  if [ "${sample}" == "sample" ]
  then
    continue
  fi

  # Read 1
  fastqc_folder_1="${raw_fastqc_folder}/${fastq1%.fastq.gz}_fastqc"
  fastqc_summary_file_1="${fastqc_folder_1}/summary.txt"
  fastqc_summary_data_1=$(awk '{print $1}' "${fastqc_summary_file_1}")
  fastqc_summary_data_1=${fastqc_summary_data_1//$'\n'/'\t'}
  fastqc_summary_data_1="${sample}_R1\t${fastqc_summary_data_1}"
  echo -e "${fastqc_summary_data_1}" >> "${raw_fastqc_folder}/raw_fastqc_summary.txt"

  # Read 2
  fastqc_folder_2="${raw_fastqc_folder}/${fastq2%.fastq.gz}_fastqc"
  fastqc_summary_file_2="${fastqc_folder_2}/summary.txt"
  fastqc_summary_data_2=$(awk '{print $1}' "${fastqc_summary_file_2}")
  fastqc_summary_data_2=${fastqc_summary_data_2//$'\n'/'\t'}
  fastqc_summary_data_2="${sample}_R2\t${fastqc_summary_data_2}"
  echo -e "${fastqc_summary_data_2}" >> "${raw_fastqc_folder}/raw_fastqc_summary.txt"

done < "${fastq_samples_file_in}"

# Plot data
Rscript "${scripts_folder}/p01_plot_fastqc.r" \
  "${raw_fastqc_folder}/raw_fastqc_summary.txt" \
  "FastQC summary, raw data" \
  "${raw_fastqc_folder}/raw_fastqc_summary.png"

# Progress report to summarise-save log
echo "Completed summarising raw fastqc results: $(date +%d%b%Y_%H:%M:%S)" >> "${summarise_save_log}"
echo "" >> "${summarise_save_log}"

# --------------------- Summarise trimmed fastqc ------------------- #

# Prepare header for the fastqc summary file
a_sample=$(awk 'NR==2 {print $1}' "${fastq_samples_file_in}")
a_fastq_file=$(awk 'NR==2 {print $2}' "${fastq_samples_file_in}")
a_fastqc_folder="${a_fastq_file%.fastq.gz}_fastqc"
a_fastqc_summary_file="${trimmed_fastqc_folder}/${a_fastqc_folder}/summary.txt"
fastqc_summary_fields=$(awk 'BEGIN { FS="\t" } ; {print $2}' "${a_fastqc_summary_file}")
fastqc_summary_header=${fastqc_summary_fields// /_}
fastqc_summary_header=${fastqc_summary_header//$'\n'/'\t'} 
fastqc_summary_header="Sample_Read\t${fastqc_summary_header}"
echo -e "${fastqc_summary_header}" > "${trimmed_fastqc_folder}/trimmed_fastqc_summary.txt"

# Collect data
while read sample fastq1 fastq2 md5
do

  # Skip the header line
  if [ "${sample}" == "sample" ]
  then
    continue
  fi

  # Read 1
  fastqc_folder_1="${trimmed_fastqc_folder}/${fastq1%.fastq.gz}_fastqc"
  fastqc_summary_file_1="${fastqc_folder_1}/summary.txt"
  fastqc_summary_data_1=$(awk '{print $1}' "${fastqc_summary_file_1}")
  fastqc_summary_data_1=${fastqc_summary_data_1//$'\n'/'\t'}
  fastqc_summary_data_1="${sample}_R1\t${fastqc_summary_data_1}"
  echo -e "${fastqc_summary_data_1}" >> "${trimmed_fastqc_folder}/trimmed_fastqc_summary.txt"

  # Read 2
  fastqc_folder_2="${trimmed_fastqc_folder}/${fastq2%.fastq.gz}_fastqc"
  fastqc_summary_file_2="${fastqc_folder_2}/summary.txt"
  fastqc_summary_data_2=$(awk '{print $1}' "${fastqc_summary_file_2}")
  fastqc_summary_data_2=${fastqc_summary_data_2//$'\n'/'\t'}
  fastqc_summary_data_2="${sample}_R2\t${fastqc_summary_data_2}"
  echo -e "${fastqc_summary_data_2}" >> "${trimmed_fastqc_folder}/trimmed_fastqc_summary.txt"

done < "${fastq_samples_file_in}"

# Plot data
Rscript "${scripts_folder}/p01_plot_fastqc.r" \
  "${trimmed_fastqc_folder}/trimmed_fastqc_summary.txt" \
  "FastQC summary, trimmed data" \
  "${trimmed_fastqc_folder}/trimmed_fastqc_summary.png"

# Progress report to summarise-save log
echo "Completed summarising trimmed fastqc results: $(date +%d%b%Y_%H:%M:%S)" >> "${summarise_save_log}"
echo "" >> "${summarise_save_log}"

# Progress report to the main log
echo "Completed summarising fastqc results: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# ------------------------ Progress report --------------------- #

# Progress report to summarise-save log
echo "Completed all summaries: $(date +%d%b%Y_%H:%M:%S)" >> "${summarise_save_log}"
echo "" >> "${summarise_save_log}"

# Progress report to main log
echo "Completed all summaries: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# -------------------------------------------------------------- #
#                       Copy results to nas                      #
# -------------------------------------------------------------- #

# Progress report to summarise-save log
echo "Started saving results to nas: $(date +%d%b%Y_%H:%M:%S)" >> "${summarise_save_log}"
echo "" >> "${summarise_save_log}"

# Progress report to main log
echo "Started saving results to nas: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
echo "" >> "${pipeline_log}"

# Make target folder on nas
ssh \
  -o "LogLevel=error" \
  -o "StrictHostKeyChecking=no" \
  -o "UserKnownHostsFile=/dev/null" \
  "${nas}" "mkdir -p ${tgt_nas_folder}"

# Copy results
rsync -ahe ssh "${project_folder}" "${nas}:${tgt_nas_folder}/"

# Logs-on-nas (to report progress after moving logs to nas) 
main_log_on_nas="${tgt_nas_folder}/${project}/${library}/${lane}/logs/a00_pipeline_${project}_${library}_${lane}.log"
script_log_on_nas="${tgt_nas_folder}/${project}/${library}/${lane}/logs/summarise_and_save.log"

# Progress report to logs-on-nas (written directly to nas by ssh)
ssh -o "LogLevel=error" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" "${nas}" \
  'echo -e "Completed saving results to nas: '"$(date +%d%b%Y_%H:%M:%S)\n"'" >> '"${main_log_on_nas}"
ssh -o "LogLevel=error" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" "${nas}" \
  'echo -e "Completed saving results to nas: '"$(date +%d%b%Y_%H:%M:%S)\n"'" >> '"${script_log_on_nas}"

####################################################################
exit
####################################################################

# -------------------------------------------------------------- #
#                            Clean-up                            #
# -------------------------------------------------------------- #

# Deleting efs: http://docs.aws.amazon.com/efs/latest/ug/wt1-clean-up.html

# Make sure that current folder is not on the efs:
# Otherwise it may be stack after unmounting during mnt deletion 
cd /home/ec2-user # !!! this is an important step!!!

# Collect information for deleting efs and efs mount target
efs_mount_tgt_creation_log="${logs_folder}/efs_mount_tgt_creation.log" # had been made earlier (during efs creation)
mount_tgt_id=$(jq -r '.MountTargetId' < "${efs_mount_tgt_creation_log}")

efs_creation_log="${logs_folder}/efs_create.log" # had been made earlier (during efs creation)
efs_id="$(jq -r '.FileSystemId' < ${efs_creation_log})"

# Unmount efs
sudo umount -l "${efs_base_folder}"

# Delete efs mount target
#http://docs.aws.amazon.com/cli/latest/reference/efs/delete-mount-target.html
aws efs delete-mount-target \
  --mount-target-id "${mount_tgt_id}" \
  --region "${region}"

# Wiat until the mount target deleted (10 attempts with 1 min breaks)
#http://docs.aws.amazon.com/cli/latest/reference/efs/describe-mount-targets.html
efs_mount_tgt_check_log="${logs_folder}/efs_mount_tgt_check.log"
efs_mount_tgt_exists="yes"
for i in {1..10}
do
  
  # Check status of the mount target
  efs_mount_tgt_check_log=$(aws efs describe-mount-targets --file-system-id "${efs_id}")
  efs_mount_tgt_check=$(jq -r '.MountTargets[0]' <<< "${efs_mount_tgt_check_log}")
  
  # Exit loop if target has been deleted
  if [ "${efs_mount_tgt_check}" == "null" ]
  then
    
    # Update flag
    efs_mount_tgt_exists="no"
    
    # Exit loop
    break
	
  fi
    
  # Whait for 1 min
  sleep 60
    
done # Next attempt

# Stop if efs mount tgt could not be deleted within 10 min
if [ "${efs_mount_tgt_exists}" == "yes" ]
then

  # Error message to logs-on-nas (written directly to nas by ssh)
  ssh -o "LogLevel=error" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" "${nas}" \
    'echo -e "efs mount target '"${mount_tgt_id}"' could not be deleted within 10 min\nScript terminated\n" >> '"${main_log_on_nas}"
  ssh -o "LogLevel=error" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" "${nas}" \
    'echo -e "efs mount target '"${mount_tgt_id}"' could not be deleted within 10 min\nScript terminated\n" >> '"${script_log_on_nas}"
  
  # Error message by e-mail
  echo -e \
  "wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
  "Failed summarise and save at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n"\
  "efs mount target ${mount_tgt_id} could not be deleted within 10 min\n\n"\
  "Script terminated. Check and stop the AWS resources manually!\n\n"\
   | mail -s "AWS-pipeline ERROR for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}" 

  exit 1
  
fi

# Delete efs
aws efs delete-file-system \
  --file-system-id "${efs_id}" \
  --region "${region}"

# Progress report to logs-on-nas (written directly to nas by ssh)
ssh -o "LogLevel=error" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" "${nas}" \
  'echo -e "Deleted efs\n\nTerminating summarise-and-save ec2 instance\n" >> '"${main_log_on_nas}"
ssh -o "LogLevel=error" -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" "${nas}" \
  'echo -e "Deleted efs\n\nTerminating summarise-and-save ec2 instance\n" >> '"${script_log_on_nas}"

# Progress report by e-mail
echo -e \
"wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
"Completed summarise and save on ${this_ec2_ip} at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n"\
 | mail -s "Completed summarise and save for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}"

# Pause to let e-mail be sent
sleep 60

# Terminate this ec2 instance
this_ec2_id="$(ec2-metadata -i)"
this_ec2_id="${this_ec2_id/instance-id: /}"
aws ec2 terminate-instances --instance-ids "${this_ec2_id}"
