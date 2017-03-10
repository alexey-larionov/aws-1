#!/bin/bash

# k02_create_efs_mount_target.sh
# Alexey Larionov
# Started: 23Dec2016
# Last updated: 15Feb2017

# Create efs mount target
# Whait until the efs mount target has passed checks
# Return a string containing mount_tgt_ip
# Exit if instance fails checks for 10 min
# Keep efs mount target creation and description logs in a specifyed folder
# Report progress to the main log

# Does not check the valitity of passed parameters !

function create_efs_mount_target(){

  # Read arguments
  local efs_id="${1}"
  local logs_folder="${2}"
  local main_log="${3}"
  local subnet_id="${4}"
  local mt_security_group_id="${5}"
  local region="${6}"
  local job_file="${7}"

  # Attempt to create a mount target
  aws efs create-mount-target \
    --file-system-id "${efs_id}" \
    --subnet-id  "${subnet_id}" \
    --security-group "${mt_security_group_id}" \
    --region "${region}" > "${logs_folder}/efs_mount_tgt_creation.log"
  
  # Get mount_tgt_id and mount_tgt_ip
  mount_tgt_id="$(jq -r '.MountTargetId' < ${logs_folder}/efs_mount_tgt_creation.log)"
  mount_tgt_ip="$(jq -r '.IpAddress' < ${logs_folder}/efs_mount_tgt_creation.log)"
  
  # Progress report
  echo "Creating a mount target for efs file system: $(date +%d%b%Y_%H:%M:%S)" >> "${main_log}"
  echo "  mount target id: ${mount_tgt_id}" >> "${main_log}"
  
  # Wiat until the mount target point becomes available (10 attempts with 1 min breaks)
  mount_tgt_check="fail"
  for i in {1..10}
  do
   
    # Get mount target description
    aws efs describe-mount-targets \
      --mount-target-id "${mount_tgt_id}" > "${logs_folder}/efs_mount_tgt_description.log"
      
    # Get mount_tgt_LifeCycleState
    mount_tgt_LifeCycleState="$(jq -r '.MountTargets[0].LifeCycleState' < ${logs_folder}/efs_mount_tgt_description.log)"
    
    if [ "${mount_tgt_LifeCycleState}" == "available" ]
    then
    
      mount_tgt_check="pass"
      
      echo "  passed check: $(date +%d%b%Y_%H:%M:%S)" >> "${main_log}"
      echo "    LifeCycleState: ${mount_tgt_LifeCycleState}" >> "${main_log}"
      echo "" >> "${main_log}"
  
      break
      
    fi
  
    # Whait for 1 min
    sleep 60 # whait 1 min
  
  done # Next attempt
  
  # Stop if the mount target has not become available within 10 min
  if [ "${mount_tgt_check}" == "fail" ]
  then
    
    # Error message to log
    echo "" >> "${main_log}"
    echo "Failed check for efs mount target for 10 min: $(date +%d%b%Y_%H:%M:%S)" >> "${main_log}"
    echo "  LifeCycleState: ${mount_tgt_LifeCycleState}" >> "${main_log}"
    echo "" >> "${main_log}"
    echo "Local script terminated" >> "${main_log}"
    echo "Check and stop the AWS resources manually" >> "${main_log}"
    echo "" >> "${main_log}"
  
    # Get additional information for e-mai message
    source "${scripts_folder}/g01_read_config.sh" "${job_file}" 
    
    # Send error message by e-mail
    echo -e \ 
    "wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
    "Failed creating efs mount target at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n"\
    "efs mount target ${mount_tgt_id} failed checks for 10 minutes\n\n"\
    "Script terminated. Check and stop the AWS resources manually!\n\n"\
     | mail -s "AWS-pipeline ERROR for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}" 
    
    # todo: attempt to termnate head-node ec2, efs file system, the mount targets and other resources? 
    exit 1
    
  fi

  # Return mount_tgt_ip
  echo "${mount_tgt_ip}"

}