#!/bin/bash

# k02_create_efs.sh
# Alexey Larionov
# Started: 23Dec2016
# Last updated: 15Feb2017

# Create efs
# Whait until the efs has passed checks
# Return a string containing efs_id
# Exit if instance fails checks for 10 min
# Keep efs creation and description logs in a specifyed folder
# Report progress to the main log

# Does not check the valitity of passed parameters !

function create_efs(){

  # Read arguments
  local efs_token="${1}"
  local logs_folder="${2}"
  local main_log="${3}"
  local region="${4}"
  local job_file="${5}"

  # Attempt to create efs
  aws efs create-file-system \
   --creation-token "${efs_token}" \
   --region "${region}" > "${logs_folder}/efs_create.log"
  
  # Get efs_id
  efs_id="$(jq -r '.FileSystemId' < ${logs_folder}/efs_create.log)"
  
  # Progress report
  echo "Creating efs file system: $(date +%d%b%Y_%H:%M:%S)" >> "${main_log}"
  echo "  efs id: ${efs_id}" >> "${main_log}"
  
  # Wiat until efs becomes available (10 attempts with 1 min breaks)
  efs_check="fail"
  for i in {1..10}
  do
   
    # Get efs description
    aws efs describe-file-systems \
      --file-system-id "${efs_id}" > "${logs_folder}/efs_description.log"
      
    # Get efs_LifeCycleState
    efs_LifeCycleState="$(jq -r '.FileSystems[0].LifeCycleState' < ${logs_folder}/efs_description.log)"
    
    if [ "${efs_LifeCycleState}" == "available" ]
    then
    
      efs_check="pass"
      
      echo "  passed check: $(date +%d%b%Y_%H:%M:%S)" >> "${main_log}"
      echo "    LifeCycleState: ${efs_LifeCycleState}" >> "${main_log}"
      echo "" >> "${main_log}"
  
      break
      
    fi
    
    # Whait for 1 min
    sleep 60
  
  done # Next attempt
  
  # Stop if efs has not become available within 10 min
  if [ "${instance_checks}" == "fail" ]
  then
  
    # Error message to log
    echo "" >> "${main_log}"
    echo "Failed check for efs file system for 10 min: $(date +%d%b%Y_%H:%M:%S)" >> "${main_log}"
    echo "  LifeCycleState: ${efs_LifeCycleState}" >> "${main_log}"
    echo "" >> "${main_log}"
    echo "Local script terminated" >> "${main_log}"
    echo "Check and stop the AWS resources manually" >> "${main_log}"
    echo "" >> "${main_log}"
    
    # Get additional information for e-mai message
    source "${scripts_folder}/g01_read_config.sh" "${job_file}" 
    
    # Send error message by e-mail
    echo -e \ 
    "wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
    "Failed creating efs at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n"\
    "efs ${efs_id} failed checks for 10 minutes\n\n"\
    "Script terminated. Check and stop the AWS resources manually!\n\n"\
     | mail -s "AWS-pipeline ERROR for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}" 
    
    # todo: attempt to termnate head-node ec2, file system and other resources? 
    exit 1
    
  fi

  # Return efs_id
  echo "${efs_id}"

}