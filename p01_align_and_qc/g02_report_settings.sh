#!/bin/bash

# g02_report_settings.sh
# Report settings for wes lane alignment pipeline
# Started: Alexey Larionov, 23Aug2016
# Last updated: Alexey Larionov, 15Mar2017

# Stop at errors
set -e

pipeline_info=$(grep "^*" "${job_file}")
pipeline_info=${pipeline_info//"*"/}

echo "----------------- e-mail notifications ---------------"
echo ""
echo "${email}"
echo ""
echo "------------------- Pipeline summary -----------------"
echo ""
echo "${pipeline_info}"
echo ""
echo "job_file: ${job_file}"
echo ""
echo "------------------- Project settings -----------------"
echo ""
echo "project: ${project}"
echo "library: ${library}"
echo "lane: ${lane}"
echo ""
echo "fastq_samples_file_in: ${fastq_samples_file_in}"
echo "bam_samples_file_out: ${bam_samples_file_out}"
echo ""
echo "fastq_suffix: ${fastq_suffix}"
echo "data_type: ${data_type}"
echo "platform: ${platform}"
echo "platform_unit_for_rg: ${platform_unit_for_rg}"
echo "remove_raw_fastq: ${remove_raw_fastq}"
echo "remove_trimmed_fastq: ${remove_trimmed_fastq}"
echo ""
echo "---------------- nas files and folders ----------------"
echo ""
echo "src_nas: ${src_nas}"
echo "src_nas_folder: ${src_nas_folder}"
echo ""
echo "tgt_nas: ${tgt_nas}"
echo "tgt_nas_folder: ${tgt_nas_folder}"
echo ""
echo "-------------------- aws settings ---------------------"
echo ""
echo "region: ${region}"
echo "availability_zone: ${availability_zone}"
echo "subnet_id: ${subnet_id}"
echo ""
echo "mt_security_group_id: ${mt_security_group_id}"
echo "ec2_security_group_id: ${ec2_security_group_id}"
echo ""
echo "key_name: ${key_name}"
echo "key_file: ${key_file}"
echo ""
echo "ami_id: ${ami_id}"
echo ""
echo "align_qc_instance_type: ${align_qc_instance_type}"
echo ""
echo "threads_bwa: ${threads_bwa}"
echo ""
echo "java_xmx: ${java_xmx}"
echo ""
echo "efs_token: ${efs_token}"
echo ""
echo "----------------- Files and folders -------------------"
echo ""
echo "ec2_base_folder: ${ec2_base_folder}"
echo "efs_base_folder: ${efs_base_folder}"
echo ""
echo "scripts_folder: ${scripts_folder}"
echo "start_script: ${start_script}"
echo ""
echo "ec2_project_folder (before mounting efs): ${ec2_project_folder}"
echo "project_folder (after mounting efs): ${project_folder}"
echo ""
echo "ec2_library_folder (before mounting efs): ${ec2_library_folder}"
echo "library_folder (after mounting efs): ${library_folder}"
echo ""
echo "ec2_lane_folder (before mounting efs): ${ec2_lane_folder}"
echo "lane_folder (after mounting efs): ${lane_folder}"
echo ""
echo "ec2_logs_folder (before mounting efs): ${ec2_logs_folder}"
echo "logs_folder (after mounting efs): ${logs_folder}"
echo ""
echo "base_fastq_folder: ${fastq_base_folder}"
echo "raw_fastq_folder: ${raw_fastq_folder}"
echo "raw_fastqc_folder: ${raw_fastqc_folder}"
echo "trimmed_fastq_folder: ${trimmed_fastq_folder}"
echo "trimmed_fastqc_folder: ${trimmed_fastqc_folder}"
echo ""
echo "bam_folder: ${bam_folder}"
echo "hla_folder: ${hla_folder}"
echo ""
echo "flagstat_folder: ${flagstat_folder}"
echo "picard_mkdup_folder: ${picard_mkdup_folder}"
echo "picard_inserts_folder: ${picard_inserts_folder}"
echo "picard_alignment_folder: ${picard_alignment_folder}"
echo "picard_hybridisation_folder: ${picard_hybridisation_folder}"
echo "picard_summary_folder: ${picard_summary_folder}"
echo "qualimap_results_folder: ${qualimap_results_folder}"
echo "samstat_results_folder: ${samstat_results_folder}"
echo ""
echo "-------------- Tools and resources ----------------"
echo ""
java -version
echo ""
"${fastqc}" --version
echo ""
echo "cutadapt version: " $("${cutadapt}" --version)
echo "cutadapt_min_len: ${cutadapt_min_len}"
echo "cutadapt_trim_qual: ${cutadapt_trim_qual}"
echo "cutadapt_remove_adapters: ${cutadapt_remove_adapters}"
echo "cutadapt_adapter_1: ${cutadapt_adapter_1}"
echo "cutadapt_adapter_2: ${cutadapt_adapter_2}"
echo ""
echo "Tools"
echo "-----"
echo ""
echo "bwa: ${bwa}"
echo "bwa_index: ${bwa_index}"
echo "bwakit_k8: ${bwakit_k8}"
echo "bwakit_postalt_js: ${bwakit_postalt_js}"
echo "bwakit_run_HLA: ${bwakit_run_HLA}"
echo ""
echo "ref_genome: ${ref_genome}"
echo ""
echo "samtools: ${samtools}"
echo "samtools_folder: ${samtools_folder}"
echo ""
echo "picard: ${picard}"
echo "htsjdk: ${htsjdk}"
echo ""

#####################################################
if [ "a" == "b" ] 
then
#####################################################

echo ""
echo "r_folder: ${r_folder}"
echo ""
echo "qualimap: ${qualimap}"
echo ""
echo "gnuplot: ${gnuplot}"
echo "LiberationSansRegularTTF: ${LiberationSansRegularTTF}"
echo ""
echo "samstat: ${samstat}"
echo ""

#####################################################
fi
#####################################################

echo "Resources" 
echo "---------"
echo ""
echo "resources_folder: ${resources_folder}"
echo ""
echo "bait_set_name: ${bait_set_name}"
echo "probes_intervals: ${probes_intervals}"
echo "targets_intervals: ${targets_intervals}"

#####################################################
if [ "a" == "b" ] 
then
#####################################################

echo "targets_bed_3: ${targets_bed_3}"
echo "targets_bed_6: ${targets_bed_6}"
echo ""
echo "Working folders"
echo "---------------"
echo ""
echo "logs_folder: ${logs_folder}"
echo "source_fastq_folder: ${source_fastq_folder}"
echo "fastqc_raw_folder: ${fastqc_raw_folder}"
echo "trimmed_fastq_folder: ${trimmed_fastq_folder}"
echo "fastqc_trimmed_folder: ${fastqc_trimmed_folder}"


echo "flagstat_folder: ${flagstat_folder}"
echo "picard_mkdup_folder: ${picard_mkdup_folder}"
echo "picard_inserts_folder: ${picard_inserts_folder}"
echo "picard_alignment_folder: ${picard_alignment_folder}"
echo "picard_hybridisation_folder: ${picard_hybridisation_folder}"
echo "picard_summary_folder: ${picard_summary_folder}"
echo "qualimap_results_folder: ${qualimap_results_folder}"
echo "samstat_results_folder: ${samstat_results_folder}"
echo "" 

#####################################################
fi
#####################################################
