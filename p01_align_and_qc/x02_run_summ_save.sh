#!/bin/bash
# Ancillary script for development and debugging

scripts_folder="/home/ec2-user/scripts/p01_align_and_qc"
job_file="/home/ec2-user/scripts/a01_jobs/template_p01_align_qc_job.txt"
pipeline_log="pp.log"
summarise_save_log="ss.log"

cd "${scripts_folder}"
"${scripts_folder}/s03_summarise_and_save.sh" "${scripts_folder}" "${job_file}" "${pipeline_log}" "${summarise_save_log}"
