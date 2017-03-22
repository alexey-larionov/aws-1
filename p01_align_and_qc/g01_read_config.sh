#!/bin/bash

# g01_read_config.sh
# Parse job config file for aws wes pipeline
# Started: Alexey Larionov, 19Dec2016
# Last updated: Alexey Larionov, 15Mar2017

# Use: g01_read_config.sh job.txt

# Stop at errors
set -e

# Config file name
job_file="${1}"

# ----------------------------------------------------------------- #
#                       e-mail notifications                        #
# ----------------------------------------------------------------- #

email=$(awk '$1=="email:" {print $2}' "${job_file}") 

# ----------------------------------------------------------------- #
#                          Project settings                         #
# ----------------------------------------------------------------- #

project=$(awk '$1=="project:" {print $2}' "${job_file}") # e.g. project1
library=$(awk '$1=="library:" {print $2}' "${job_file}") # e.g. library1
lane=$(awk '$1=="lane:" {print $2}' "${job_file}") # e.g. lane1

fastq_samples_file_in=$(awk '$1=="samples:" {print $2}' "${job_file}") # e.g. samples_3.txt (will be in raw fastq folder)
bam_samples_file_out=$(awk '$1=="samples:" {print $2}' "${job_file}") # e.g. samples_3.txt (will be in lane folder)

fastq_suffix=$(awk '$1=="fastq_suffix:" {print $2}' "${job_file}") # e.g. .fastq.gz
data_type=$(awk '$1=="data_type:" {print $2}' "${job_file}") # e.g. pe (se is not yet supported)
platform=$(awk '$1=="platform:" {print $2}' "${job_file}") # e.g. illumina (other platforms are not expected)
platform_unit_for_rg=$(awk '$1=="platform_unit_for_rg:" {print $2}' "${job_file}") # e.g. from_illumina_fastq or project_library_lane

remove_raw_fastq=$(awk '$1=="remove_raw_fastq:" {print $2}' "${job_file}") # e.g. no
remove_trimmed_fastq=$(awk '$1=="remove_trimmed_fastq:" {print $2}' "${job_file}") # e.g. yes

# ----------------------------------------------------------------- #
#                       nas files and folders                       #
# ----------------------------------------------------------------- #

src_nas=$(awk '$1=="src_nas:" {print $2}' "${job_file}") # e.g. admin@mgqnap2.medschl.cam.ac.uk
src_nas_folder=$(awk '$1=="src_nas_folder:" {print $2}' "${job_file}") # e.g. /share/user/project/source_fastq

tgt_nas=$(awk '$1=="tgt_nas:" {print $2}' "${job_file}") # e.g. admin@mgqnap2.medschl.cam.ac.uk
tgt_nas_folder=$(awk '$1=="tgt_nas_folder:" {print $2}' "${job_file}") # e.g. /share/user

# ----------------------------------------------------------------- #
#                              aws settings                         #
# ----------------------------------------------------------------- #

# Region and subnet
region=$(awk '$1=="region:" {print $2}' "${job_file}") # e.g. eu-west-1
availability_zone=$(awk '$1=="availability_zone:" {print $2}' "${job_file}") # e.g. eu-west-1b
subnet_id=$(awk '$1=="subnet_id:" {print $2}' "${job_file}") # e.g. subnet-1cdf5044

# Security groups
mt_security_group_id=$(awk '$1=="mt_security_group_id:" {print $2}' "${job_file}") # e.g. sg-f276e894
ec2_security_group_id=$(awk '$1=="ec2_security_group_id:" {print $2}' "${job_file}") # e.g. sg-2ef16548

# Key(s)
key_name=$(awk '$1=="key_name:" {print $2}' "${job_file}") # e.g. k01_01Dec2016
key_file=$(awk '$1=="key_file:" {print $2}' "${job_file}") # e.g. /home/ec2-user/.ssh/k01_01Dec2016.pem

# ami(s)
ami_id=$(awk '$1=="ami_id:" {print $2}' "${job_file}") # e.g. ami-7d3d1b0e

# Instance(s) type
align_qc_instance_type=$(awk '$1=="align_qc_instance_type:" {print $2}' "${job_file}") # e.g. m4.4xlarge

# Number of threads for BWA
threads_bwa=$(awk '$1=="threads_bwa:" {print $2}' "${job_file}") # e.g. 4

# Max memory allocated for java in Picard/GATK calls
java_xmx=$(awk '$1=="java_xmx:" {print $2}' "${job_file}") # e.g. 12g

# token for efs creation
efs_token=$(awk '$1=="efs_token:" {print $2}' "${job_file}") # e.g. wes_efs

# ----------------------------------------------------------------- #
#                          Files and folders                        #
# ----------------------------------------------------------------- #

# aws base folders
ec2_base_folder=$(awk '$1=="ec2_base_folder:" {print $2}' "${job_file}") # e.g. /home/ec2-user

# efs base folder
efs_base_folder=$(awk '$1=="efs_base_folder:" {print $2}' "${job_file}") # e.g. efs
efs_base_folder="${ec2_base_folder}/${efs_base_folder}"

# Scripts folder and start script
scripts_folder=$(awk '$1=="scripts_folder:" {print $2}' "${job_file}") # e.g. scripts/p01_align_and_qc
scripts_folder="${ec2_base_folder}/${scripts_folder}"
start_script=$(awk '$1=="start_script:" {print $2}' "${job_file}") # e.g. a00_start_pipeline.sh
start_script="${scripts_folder}/${start_script}"

# Project folder
ec2_project_folder="${ec2_base_folder}/${project}" # before mounting efs
project_folder="${efs_base_folder}/${project}" # after mounting efs

# Library folder
ec2_library_folder="${ec2_project_folder}/${library}" # before mounting efs
library_folder="${project_folder}/${library}" # after mounting efs

# Lane folder
ec2_lane_folder="${ec2_library_folder}/${lane}" # before mounting efs
lane_folder="${library_folder}/${lane}" # after mounting efs

# logs folder
logs_folder=$(awk '$1=="logs_folder:" {print $2}' "${job_file}") # e.g. f01_logs
ec2_logs_folder="${ec2_lane_folder}/${logs_folder}" # before mounting efs
logs_folder="${lane_folder}/${logs_folder}" # after mounting efs

# fastq folders
raw_fastq_folder=$(awk '$1=="raw_fastq_folder:" {print $2}' "${job_file}") # e.g. f02_fastq/raw_fastq
raw_fastq_folder="${lane_folder}/${raw_fastq_folder}"

fastq_samples_file_in="${raw_fastq_folder}/${fastq_samples_file_in}"

trimmed_fastq_folder=$(awk '$1=="trimmed_fastq_folder:" {print $2}' "${job_file}") # e.g. f02_fastq/trimmed_fastq
trimmed_fastq_folder="${lane_folder}/${trimmed_fastq_folder}"

# fastqc folders
raw_fastqc_folder=$(awk '$1=="raw_fastqc_folder:" {print $2}' "${job_file}") # e.g. f03_fastqc/raw_fastqc
raw_fastqc_folder="${lane_folder}/${raw_fastqc_folder}"

trimmed_fastqc_folder=$(awk '$1=="trimmed_fastqc_folder:" {print $2}' "${job_file}") # e.g. f03_fastqc/trimmed_fastqc
trimmed_fastqc_folder="${lane_folder}/${trimmed_fastqc_folder}"

# bam folders
bam_folder=$(awk '$1=="bam_folder:" {print $2}' "${job_file}") # e.g. f03_bam
bam_folder="${lane_folder}/${bam_folder}"

bam_samples_file_out="${lane_folder}/${bam_samples_file_out}"

hla_folder=$(awk '$1=="hla_folder:" {print $2}' "${job_file}") # e.g. f03_bam/hla
hla_folder="${lane_folder}/${hla_folder}"

# bam stats folders

flagstat_folder=$(awk '$1=="flagstat_folder:" {print $2}' "${job_file}") # e.g. f04_bam_stats/f01_flagstat
flagstat_folder="${lane_folder}/${flagstat_folder}"

picard_mkdup_folder=$(awk '$1=="picard_mkdup_folder:" {print $2}' "${job_file}") # e.g. f04_bam_stats/f02_picard/f01_mkdup_metrics
picard_mkdup_folder="${lane_folder}/${picard_mkdup_folder}"

picard_inserts_folder=$(awk '$1=="picard_inserts_folder:" {print $2}' "${job_file}") # e.g. f04_bam_stats/f02_picard/f02_inserts_metrics
picard_inserts_folder="${lane_folder}/${picard_inserts_folder}"

picard_alignment_folder=$(awk '$1=="picard_alignment_folder:" {print $2}' "${job_file}") # e.g. f04_bam_stats/f02_picard/f03_alignment_metrics
picard_alignment_folder="${lane_folder}/${picard_alignment_folder}"

picard_hybridisation_folder=$(awk '$1=="picard_hybridisation_folder:" {print $2}' "${job_file}") # e.g. f04_bam_stats/f02_picard/f04_hybridisation_metrics
picard_hybridisation_folder="${lane_folder}/${picard_hybridisation_folder}"

picard_summary_folder=$(awk '$1=="picard_summary_folder:" {print $2}' "${job_file}") # e.g. f04_bam_stats/f02_picard/f05_metrics_summaries
picard_summary_folder="${lane_folder}/${picard_summary_folder}"

qualimap_results_folder=$(awk '$1=="qualimap_results_folder:" {print $2}' "${job_file}") # e.g. f04_bam_stats/f03_qualimap
qualimap_results_folder="${lane_folder}/${qualimap_results_folder}"

samstat_results_folder=$(awk '$1=="samstat_results_folder:" {print $2}' "${job_file}") # e.g. f04_bam_stats/f04_samstat
samstat_results_folder="${lane_folder}/${samstat_results_folder}"

# ----------------------------------------------------------------- #
#                         Tools and resources                       #
# ----------------------------------------------------------------- #

# ----------- Tools ---------- #

#java
#R
#python-?

# Tools folder 
tools_folder=$(awk '$1=="tools_folder:" {print $2}' "${job_file}") # e.g. tools
tools_folder="${ec2_base_folder}/${tools_folder}"

# FastQC
fastqc=$(awk '$1=="fastqc:" {print $2}' "${job_file}") # e.g. fastqc/fastqc_v0.11.3/fastqc
fastqc="${tools_folder}/${fastqc}"

# Cutadapt settings

cutadapt=$(awk '$1=="cutadapt:" {print $2}' "${job_file}") # e.g.python/python_2.7.13/bin/cutadapt
cutadapt="${tools_folder}/${cutadapt}"

cutadapt_min_len=$(awk '$1=="cutadapt_min_len:" {print $2}' "${job_file}") # e.g. 50
cutadapt_trim_qual=$(awk '$1=="cutadapt_trim_qual:" {print $2}' "${job_file}") # e.g. 20
cutadapt_remove_adapters=$(awk '$1=="cutadapt_remove_adapters:" {print $2}' "${job_file}") # yes or no
cutadapt_adapter_1=$(awk '$1=="cutadapt_adapter_1:" {print $2}' "${job_file}") # e.g. CTGTCTCTTATACACATCTCCGAGCCCACGAGACNNNNNNNNATCTCGTATGCCGTCTTCTGCTTG
cutadapt_adapter_2=$(awk '$1=="cutadapt_adapter_2:" {print $2}' "${job_file}") # e.g. CTGTCTCTTATACACATCTGACGCTGCCGACGANNNNNNNNGTGTAGATCTCGGTGGTCGCCGTATCATT

bwa=$(awk '$1=="bwa:" {print $2}' "${job_file}") # e.g. bwa/bwa-0.7.12/bwa
bwa="${tools_folder}/${bwa}"

bwa_index=$(awk '$1=="bwa_index:" {print $2}' "${job_file}") # e.g. bwa/bwa_GRCh38/hs38DH.fa
bwa_index="${tools_folder}/${bwa_index}"

bwakit_k8=$(awk '$1=="bwakit_k8:" {print $2}' "${job_file}") # e.g. bwa/bwakit-0.7.15/k8
bwakit_k8="${tools_folder}/${bwakit_k8}"

bwakit_postalt_js=$(awk '$1=="bwakit_postalt_js:" {print $2}' "${job_file}") # e.g. bwa/bwakit-0.7.15/bwa-postalt.js
bwakit_postalt_js="${tools_folder}/${bwakit_postalt_js}"

bwakit_run_hla=$(awk '$1=="bwakit_run_hla:" {print $2}' "${job_file}") # e.g. bwa/bwakit-0.7.15/run-HLA
bwakit_run_hla="${tools_folder}/${bwakit_run_hla}"

ref_genome=$(awk '$1=="ref_genome:" {print $2}' "${job_file}") # e.g. bwa/bwa_GRCh38/hs38DH.fa
ref_genome="${tools_folder}/${ref_genome}"

samtools=$(awk '$1=="samtools:" {print $2}' "${job_file}") # e.g. samtools/samtools-1.3.1/bin/samtools
samtools="${tools_folder}/${samtools}"

samtools_folder=$(awk '$1=="samtools_folder:" {print $2}' "${job_file}") # e.g. samtools/samtools-1.3.1/bin
samtools_folder="${tools_folder}/${samtools_folder}"
PATH="${samtools_folder}:${PATH}" # samstat needs samtools in the PATH

picard=$(awk '$1=="picard:" {print $2}' "${job_file}") # e.g. picard/picard-2.9.0/picard.jar
picard="${tools_folder}/${picard}"

htsjdk=$(awk '$1=="htsjdk:" {print $2}' "${job_file}") # e.g. htsjdk/htsjdk-2.9.1/htsjdk-unspecified-SNAPSHOT-all.jar
htsjdk="${tools_folder}/${htsjdk}"

##################################################################################################
if [ "a" == "b" ]
then
##################################################################################################

r_folder=$(get_parameter "r_folder") # e.g. r/R-3.2.0/bin
r_folder="${tools_folder}/${r_folder}"
PATH="${r_folder}:${PATH}" # picard, GATK and Qualimap need R in the PATH

qualimap=$(get_parameter "qualimap") # e.g. qualimap/qualimap_v2.1.1/qualimap.modified
qualimap="${tools_folder}/${qualimap}"

gnuplot=$(get_parameter "gnuplot") # e.g. gnuplot/gnuplot-5.0.1/bin/gnuplot
gnuplot="${tools_folder}/${gnuplot}"

LiberationSansRegularTTF=$(get_parameter "LiberationSansRegularTTF") # e.g. fonts/liberation-fonts-ttf-2.00.1/LiberationSans-Regular.ttf
LiberationSansRegularTTF="${tools_folder}/${LiberationSansRegularTTF}"

samstat=$(get_parameter "samstat") # e.g. samstat/samstat-1.5.1/bin/samstat
samstat="${tools_folder}/${samstat}"

##################################################################################################
fi
##################################################################################################

# ----------- Resources ---------- #

resources_folder=$(awk '$1=="resources_folder:" {print $2}' "${job_file}") # e.g. /scratch/medgen/resources

bait_set_name=$(awk '$1=="bait_set_name:" {print $2}' "${job_file}") # e.g. nexterarapidcapture_exome

probes_intervals=$(awk '$1=="probes_intervals:" {print $2}' "${job_file}") # e.g. nexterarapidcapture_exome/b38/nexterarapidcapture_exome_probes_hg38.interval_list
probes_intervals="${resources_folder}/${probes_intervals}"

targets_intervals=$(awk '$1=="targets_intervals:" {print $2}' "${job_file}") # e.g. nexterarapidcapture_exome/b38/nexterarapidcapture_exome_targets_hg38.interval_list
targets_intervals="${resources_folder}/${targets_intervals}"

##################################################################################################
if [ "a" == "b" ]
then
##################################################################################################

targets_bed_3=$(get_parameter "targets_bed_3") 
# e.g. illumina_nextera/nexterarapidcapture_exome_targetedregions_v1.2.b37.bed
targets_bed_3="${resources_folder}/${targets_bed_3}"

targets_bed_6=$(get_parameter "targets_bed_6") 
# e.g. illumina_nextera/nexterarapidcapture_exome_targetedregions_v1.2.b37.6.bed
targets_bed_6="${resources_folder}/${targets_bed_6}"

# ----------- Working folders ---------- #

bam_folder=$(get_parameter "bam_folder") # e.g. f03_bam
bam_folder="${lane_folder}/${bam_folder}"

flagstat_folder=$(get_parameter "flagstat_folder") # e.g. f04_bam_stats/f01_flagstat
flagstat_folder="${lane_folder}/${flagstat_folder}"

picard_mkdup_folder=$(get_parameter "picard_mkdup_folder") # e.g. f04_bam_stats/f02_picard/f01_mkdup_metrics
picard_mkdup_folder="${lane_folder}/${picard_mkdup_folder}"

picard_inserts_folder=$(get_parameter "picard_inserts_folder") # e.g. f04_bam_stats/f02_picard/f02_inserts_metrics
picard_inserts_folder="${lane_folder}/${picard_inserts_folder}"

picard_alignment_folder=$(get_parameter "picard_alignment_folder") # e.g. f04_bam_stats/f02_picard/f03_alignment_metrics
picard_alignment_folder="${lane_folder}/${picard_alignment_folder}"

picard_hybridisation_folder=$(get_parameter "picard_hybridisation_folder") # e.g. f04_bam_stats/f02_picard/f04_hybridisation_metrics
picard_hybridisation_folder="${lane_folder}/${picard_hybridisation_folder}"

picard_summary_folder=$(get_parameter "picard_summary_folder") # e.g. f04_bam_stats/f02_picard/f05_metrics_summaries
picard_summary_folder="${lane_folder}/${picard_summary_folder}"

qualimap_results_folder=$(get_parameter "qualimap_results_folder") # e.g. f04_bam_stats/f03_qualimap
qualimap_results_folder="${lane_folder}/${qualimap_results_folder}"

##################################################################################################
fi
##################################################################################################
