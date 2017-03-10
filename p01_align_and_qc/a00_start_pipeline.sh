#!/bin/bash

# a00_start_pipeline.sh
# Start wes lane alignment and QC
# Started: Alexey Larionov, 27Jul2016
# Last updated: Alexey Larionov, 15Feb2017

# Stop at errors
set -e

## Read parameters
job_file="${1}"
scripts_folder="${2}"

# Read job's settings
source "${scripts_folder}/g01_read_config.sh"  "${job_file}" # note source

# ----------------------------------------------------------- #
#                          Start log                          #
# ----------------------------------------------------------- #

# Place lane pipeline log to the head ec2 until efs is mounted
mkdir -p "${ec2_logs_folder}"
ec2_pipeline_log="${ec2_logs_folder}/a00_pipeline_${project}_${library}_${lane}.log"

# Report settings to the log
echo "WES lane alignment and QC" > "${ec2_pipeline_log}"
echo "Started: $(date +%d%b%Y_%H:%M:%S)" >> "${ec2_pipeline_log}"
echo "" >> "${ec2_pipeline_log}"

echo "====================== Settings ======================" >> "${ec2_pipeline_log}"
echo "" >> "${ec2_pipeline_log}"

source "${scripts_folder}/g02_report_settings.sh" &>> "${ec2_pipeline_log}" # note source

echo "=================== Pipeline steps ===================" >> "${ec2_pipeline_log}"
echo "" >> "${ec2_pipeline_log}"

# ----------------------------------------------------------- #
#                  Progress report by e-mail                  #
# ----------------------------------------------------------- #

# Get current ami id
this_ec2_ami_id="$(ec2-metadata -a)"
this_ec2_ami_id="${this_ec2_ami_id/ami-id: /}"

# Get current ec2 ip
this_ec2_public_ip="$(ec2-metadata -v)"
this_ec2_public_ip="${this_ec2_public_ip/public-ipv4: /}"

# Send e-mail
echo -e \
"wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
"Started at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n"\
"ami id: ${this_ec2_ami_id}\n\n"\
"head ec2 instance public ip: ${this_ec2_public_ip}\n\n"\
 | mail -s "Started wes alignment pipeline for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}"

# ----------------------------------------------------------- #
#                       Start pipeline                        #
# ----------------------------------------------------------- #

# Start script to mount efs, copy source data and dispatch samples
# This script is executed on the head node
"${scripts_folder}/s01_copy_and_dispatch.sh" \
  "${job_file}" \
  "${ec2_pipeline_log}" \
  "${ec2_logs_folder}" \
  "${scripts_folder}" & # do not wait until completion

disown $! # Disown the launched process, so the terminal (connection) can be closed w/o affecting the launched script.  
          # If not completed normally, the orphaned process still will be closed when the head instance is terminated
          # (normally the head instance is termionated  by s03_summarise_and_save.sh)
