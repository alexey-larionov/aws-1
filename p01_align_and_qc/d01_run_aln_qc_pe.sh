#!/bin/bash

sample="IHCAP_84_01"
job_file="/home/ec2-user/scripts/a01_jobs/template_p01_align_qc_job.txt"
scripts_folder="/home/ec2-user/scripts/p01_align_and_qc"
pipeline_log="pp.log"
data_type="pe"

cd "${scripts_folder}"

"${scripts_folder}/s02b_align_and_qc_pe.sh" \
         "${sample}" \
         "${job_file}" \
         "${scripts_folder}" \
         "${pipeline_log}" \
         "${data_type}"
