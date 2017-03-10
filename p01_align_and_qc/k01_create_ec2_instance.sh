#!/bin/bash

# k01_create_ec2_instance.sh
# Alexey Larionov
# Started: 23Dec2016
# Last updated: 15Feb2017

# Create ec2 instance
# Whait until the instance has passed checks
# Return a string containing instance private ip
# Exit if instance fails checks for 10 min
# Report progress to the log

# Does not check the valitity of passed parameters !

function create_ec2_instance(){

  # Read arguments
  local lable="${1}"
  local interim_logs_folder="${2}"
  local main_log="${3}"
  local ami_id="${4}"
  local instance_type="${5}"
  local key_name="${6}"
  local region="${7}"
  local subnet="${8}"
  local security_group="${9}"
  local job_file="${10}"
  
  # Make file names for interim logs
  local create_log="$(mktemp ${interim_logs_folder}/ec2_create_${lable}_XXXXXX_tmp.log)"
  local check_log="$(mktemp ${interim_logs_folder}/ec2_check_${lable}_XXXXXX_tmp.log)"
  
  # Attempt to start the instance
  aws ec2 run-instances \
    --image-id "${ami_id}" \
    --count 1 \
    --instance-type "${instance_type}" \
    --key-name "${key_name}" \
    --security-group-ids "${security_group}" \
    --subnet-id "${subnet}" \
    --region "${region}" > "${create_log}"
    
  # Get instance id and ip
  local instance_id=$(jq -r '.Instances[0].InstanceId' < "${create_log}")
  local instance_private_ip=$(jq -r '.Instances[0].PrivateIpAddress' < "${create_log}")
  
  # Progress report to log
  echo "Launched ec2 instance: $(date +%d%b%Y_%H:%M:%S)" >> "${main_log}"
  echo "  instance_id: ${instance_id}" >> "${main_log}"
  echo "  instance_private_ip: ${instance_private_ip}" >> "${main_log}"

  # Wiat until the instance passes checks (10 attempts with 1 min breaks)
  #http://docs.aws.amazon.com/cli/latest/reference/ec2/describe-instance-status.html
  local instance_checks="fail"
  for i in {1..10}
  do
    
    aws ec2 describe-instance-status \
      --instance-id "${instance_id}" > "${check_log}"
    
    local instance_state=$(jq -r '.InstanceStatuses[0].InstanceState.Name' < "${check_log}")
    local system_reachability=$(jq -r '.InstanceStatuses[0].SystemStatus.Status' < "${check_log}")
    local instance_reachability=$(jq -r '.InstanceStatuses[0].InstanceStatus.Status' < "${check_log}")
      
    if [ "${instance_state}" == "running" ] && \
       [ "${system_reachability}" == "ok" ] && \
       [ "${instance_reachability}" == "ok" ]
    then
    
      instance_checks="pass"

      # Progress report to log
      echo "  passed checks: $(date +%d%b%Y_%H:%M:%S)" >> "${main_log}"
      echo "    instance_state: ${instance_state}" >> "${main_log}"
      echo "    system_reachability: ${system_reachability}" >> "${main_log}"
      echo "    instance_reachability: ${instance_reachability}" >> "${main_log}"
      echo "" >> "${main_log}"
      
      break
    fi
    
    # Whait for 1 min
    sleep 60
    
  done # Next attempt
  
  # Stop if instance could not be started within 10 min
  if [ "${instance_checks}" == "fail" ]
  then

    # Error message to log
    echo "Instance ${instance_id} failed checks for 10 minutes" >> "${main_log}"
    echo "Script terminated. Check and stop the AWS resources manually" >> "${main_log}"
    
    # Error message to std out
    echo "Instance ${instance_id} failed checks for 10 minutes"
    echo "Script terminated. Check and stop the AWS resources manually"
    
    # Get additional information for e-mai message
    source "${scripts_folder}/g01_read_config.sh" "${job_file}"
    
    # Send error message by e-mail
    echo -e \ 
    "wes alignment pipeline for ${project} ${library} ${lane} ${data_type}\n\n"\
    "Failed creating ec2 instance on ${this_ec2_ip} at $(date +%H:%M:%S) on $(date +%d%b%Y)\n\n"\
    "Instance ${instance_id} failed checks for 10 minutes\n\n"\
    "Script terminated. Check and stop the AWS resources manually!\n\n"\
     | mail -s "AWS-pipeline ERROR for ${project} ${library} ${lane} ${data_type}" -r "AWS-pipeline<${email}>" "${email}" 

    # todo: attempt to termnate head-node ec2, file system and other resources? 
    exit 1
    
  fi

  # Delete intermediate logs
  rm -f "${create_log}" "${check_log}"
    
  # Return instance ip
  echo "${instance_private_ip}"
  
}
