#!/bin/bash

# s02_align_and_qc_pe.sh
# Wes sample alignment and QC
# Started: Alexey Larionov, 12Dec2016
# Last updated: Alexey Larionov, 15Mar2017

# Stop at any errors
set -e

# Read parameters
sample="${1}"
job_file="${2}"
scripts_folder="${3}"
pipeline_log="${4}"
data_type="${5}"

# Update pipeline log
echo "Started ${sample}_${data_type}: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"

# Progress report to the job log
echo "Wes sample alignment and QC"
echo "Started: $(date +%d%b%Y_%H:%M:%S)"
echo ""
echo "sample: ${sample} ${data_type}"
echo ""

echo "====================== Settings ======================"
echo ""

source "${scripts_folder}/g01_read_config.sh" "${job_file}"
source "${scripts_folder}/g02_report_settings.sh"

echo "====================================================="
echo ""

#########################################################################################################
#if [ "a" == "b" ]
#then
#########################################################################################################

# ------- FastQC before trimming ------- #

# Progress report
echo "Started FastQC before trimming"

# Get names of fastq files
fastq_1=$(awk -v s="${sample}" '$1==s {print $2}' "${fastq_samples_file_in}")
raw_fastq_1="${raw_fastq_folder}/${fastq_1}"
  
fastq_2=$(awk -v s="${sample}" '$1==s {print $3}' "${fastq_samples_file_in}")
raw_fastq_2="${raw_fastq_folder}/${fastq_2}"

# FastQC read 1 and read 2 in parallel
"${fastqc}" --quiet --extract -o "${raw_fastqc_folder}" "${raw_fastq_1}" &
"${fastqc}" --quiet --extract -o "${raw_fastqc_folder}" "${raw_fastq_2}" &

# Wait for completion of both reads (if pe) and report progress
wait
echo "Completed FastQC before trimming: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Trimming fastq files ------- #

# Progress report
echo "Started trimming fastq files"

#${file_name%${sf}}_trimmed${sf}
# File names
trimmed_fastq_1="${trimmed_fastq_folder}/${fastq_1%.${fastq_suffix}}_trim.${fastq_suffix}"
trimmed_fastq_2="${trimmed_fastq_folder}/${fastq_2%.${fastq_suffix}}_trim.${fastq_suffix}"
trimming_log="${trimmed_fastq_folder}/${sample}_trimming.log"

# Submit sample to cutadapt
if [ "${cutadapt_remove_adapters}" == "yes" ] || [ "${cutadapt_remove_adapters}" == "Yes" ]
then
  
  # Trim low-quality bases on both ends and remove adapters, 
  # then discard reads, if they are becoming too short;
  # Keep both fastq files cyncronised
  "${cutadapt}" \
    -q "${cutadapt_trim_qual}","${cutadapt_trim_qual}" \
    -m "${cutadapt_min_len}" \
    -a "${cutadapt_adapter_1}" \
    -A "${cutadapt_adapter_2}" \
    -o "${trimmed_fastq_1}" \
    -p "${trimmed_fastq_2}" \
    "${raw_fastq_1}" "${raw_fastq_2}" > "${trimming_log}"
    
elif [ "${cutadapt_remove_adapters}" == "no" ] || [ "${cutadapt_remove_adapters}" == "No" ]
then 

  # Trim low-quality bases on both ends, then discard reads, 
  # if they are becoming too short; keep both fastq files cyncronised
  "${cutadapt}" \
    -q "${cutadapt_trim_qual}","${cutadapt_trim_qual}" \
    -m "${cutadapt_min_len}" \
    -o "${trimmed_fastq_1}" \
    -p "${trimmed_fastq_2}" \
    "${raw_fastq_1}" "${raw_fastq_2}" > "${trimming_log}"

else
  echo "Wrong cutadapt_remove_adapters settings:"
  echo "${cutadapt_remove_adapters}"
  echo "" 
  echo "Should be yes or no"
  echo ""  
  echo "Script terminated"
  echo ""
  exit 1
fi

# Optional removal of raw fastq files
if [ "${remove_raw_fastq}" == "yes" ] 
then
  rm -f "${raw_fastq_1}" "${raw_fastq_2}"
fi

# Progress report
echo "Completed trimming of fastq files: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- FastQC after trimming ------- #

# Progress report
echo "Started FastQC after trimming"

# FastQC read 1 and read 2 in parallel
"${fastqc}" --quiet --extract -o "${trimmed_fastqc_folder}" "${trimmed_fastq_1}" &
"${fastqc}" --quiet --extract -o "${trimmed_fastqc_folder}" "${trimmed_fastq_2}" &

# Wait for completion of both reads and report progress
wait
echo "Completed FastQC after trimming: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------ Prepare read group info ------- #

id="${project}_${library}_${lane}_${sample}"
sm="${sample}"
lb="${project}_${library}"
pl="${platform}"

# Platform Unit
if [ "${platform_unit_for_rg}" == "from_illumina_fastq" ] 
then 
     
  # Read @<instrument>:<run number>:<flowcell ID>:<lane> from the 1st line of the 1st fastq
  # Assuming zipped illumina fastq files, and no fastq files merged from different lanes
  pu=$(gunzip -c "${trimmed_fastq_1}" | head -n 1 | sed s/^@// | awk 'BEGIN{FS=":"} {print $1"_"$2"_"$3"_"$4}') 
  
fi

if [ "${platform_unit_for_rg}" == "project_library_lane" ] 
then
  # Use a generic line description as a Platform Unit
  pu="${project}_${library}_${lane}"
fi

rg='@RG\tID:'"${id}"'\tSM:'"${sm}"'\tLB:'"${lb}"'\tPL:'"${pl}"'\tPU:'"${pu}"

echo "Read group info:"
echo "ID: ${id}"
echo "SM: ${sm}"
echo "LB: ${lb}"
echo "PL: ${pl}"
echo "PU (${platform_unit_for_rg}): ${pu}"
echo ""

# ------- Alignment ------- #
# Loading bwa index to RAM on ec2 may take ~30 min ...
# e.g. as noted here: https://www.biostars.org/p/142920/

# Progress report
echo "Started alignment"

# File names
raw_bam_file="${sample}_${lane}_raw.bam"
raw_bam="${bam_folder}/${raw_bam_file}"

alignment_log="${sample}_${lane}_alignment.log"
alignment_log="${bam_folder}/${alignment_log}"

hla="${hla_folder}/${sample}_${lane}_hla"

# Align (todo: check if adding -M is still necessary?) |
# Postprocess alternate loci and prepare data for HLA typing | 
# SAM -> BAM 
"${bwa}" mem -M -t"${threads_bwa}" -R"${rg}" "${bwa_index}" "${trimmed_fastq_1}" "${trimmed_fastq_2}" 2> "${alignment_log}" | \
"${bwakit_k8}" "${bwakit_postalt_js}" -p "${hla}" "${bwa_index}.alt" | \
"${samtools}" view -1 - > "${raw_bam}"

# Finalise HLA typing
"${bwakit_run_hla}" "${hla}" > "${hla}".top 2> "${hla}".log
touch "${hla}".HLA-dummy.gt 
cat "${hla}".HLA*.gt | grep ^GT | cut -f2- > "${hla}".all
rm -f "${hla}".HLA*

# The alignment scripts are based on the output of run-bwa from bwa.ikt

# BWA options:
# -M  Mark shorter split hits as secondary
# This is done for Picard compatibility: it does not accept multiple primary alignments. 

# Quote about -M option from bwa FAQ (of 2010) at http://bio-bwa.sourceforge.net/ 
# Q: With BWA-MEM/BWA-SW, my tools are complaining about multiple primary alignments. 
#    Is it a bug?
# A: It is not. Multi-part alignments are possible in the presence of structural 
#    variations, gene fusion or reference misassembly. However, representing 
#    multi-part alignments in SAM has not been finalized. To make BWA work with 
#    your tools, please use option `-M' to flag extra hits as secondary. 

# -t  Number of threads: adjust to the type of instance used for alignment and qc!

# samtools options:
# -l BAM output with fast compression

# Optional removal of trimmed fastq files
if [ "${remove_trimmed_fastq}" == "yes" ] 
then
  rm -f "${trimmed_fastq_1}" "${trimmed_fastq_2}"
fi

# Progress report
echo "Completed alignment: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Sort by name ------- #
# This step maybe excessive: 
# it is required for fixmate (see below)
# BAM sorting at this stage depends how the original fastq 
# files were sorted and how bwa handles the bam sorting. 

# Progress report
echo "Started sorting by name (required by fixmate)"

# Sorted bam file name
nsort_bam_file="${sample}_${lane}_nsort.bam"
nsort_bam="${bam_folder}/${nsort_bam_file}"

# Sort using samtools (later may be switched to picard SortSam?)
${samtools} sort -n -o "${nsort_bam}" -T "${nsort_bam/_nsort.bam/_nsort_tmp}_${RANDOM}" "${raw_bam}"

# Remove raw bam
rm -f "${raw_bam}"

# Progress report
echo "Completed sorting by name: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Fixmate ------- #
# maybe 
# Adds correct information about the mate reads:
# mate coordinates, ISIZE and mate related flags
# requires a name-sorted bam. 
# http://www.htslib.org/doc/samtools.html

# Progress report
echo "Started fixing mate-pairs"

# Fixmated bam file name  
fixmate_bam_file="${sample}_${lane}_fixmate.bam"
fixmate_bam="${bam_folder}/${fixmate_bam_file}"

# Fixmate (later may be switched to Picard FixMateInformation)
${samtools} fixmate "${nsort_bam}" "${fixmate_bam}"

# Remove nsorted bam
rm -f "${nsort_bam}"

# Progress report
echo "Completed fixing mate-pairs: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Sort by coortdinate ------- #
# This step is required because the downstream 
# tools may expect the bam being coordinate-sorted 

# Progress report
echo "Started sorting by coordinate"

# Sorted bam file name
sort_bam_file="${sample}_${lane}_fixmate_sort.bam"
sort_bam="${bam_folder}/${sort_bam_file}"

# Sort using samtools (later may be switched to picard SortSam)
${samtools} sort -o "${sort_bam}" -T "${sort_bam/_sort.bam/_sort_tmp}_${RANDOM}" "${fixmate_bam}"

# Remove fixmated bam
rm -f "${fixmate_bam}"

# Progress report
echo "Completed sorting by coordinate: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- FixBAMFile ------- #
# Fixing Bin field errors 
# ERROR: bin field of BAM record does not equal value computed based on 
# alignment start and end, and length of sequence to which read is aligned
# http://gatkforums.broadinstitute.org/gatk/discussion/4290/sam-bin-field-error-for-the-gatk-run
# Solution: htsjdk.samtools.FixBAMFile - as used below
# https://sourceforge.net/p/samtools/mailman/message/31853465/
# https://github.com/samtools/htsjdk/blob/master/src/main/java/htsjdk/samtools/FixBAMFile.java
#

# Progress report
echo "Started fixing bam bins field errors"

# File name for cleaned bam
binfix_bam="${sample}_${lane}_fixmate_sort_binfix.bam"
binfix_bam="${bam_folder}/${binfix_bam}"

# Fix Bin field errors
java -Xmx"${java_xmx}" -cp "${htsjdk}" htsjdk.samtools.FixBAMFile \
  "${sort_bam}" \
  "${binfix_bam}"

# Remove cleaned bam
rm -f "${sort_bam}"

# Progress report
echo "Completed fixing bam bins field errors: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- CleanSam ------- #
# Soft-clipping beyond-end-of-reference alignments and setting MAPQ to 0 for unmapped reads
# BWA samse/sampe (but not BWA MEM) may generate reads flagged as unmapped with MAPQ > 0
# Correcting these is required to pass Picard strict validation.

# Indexing caused an error during testing in old picard versions. 

# Progress report
echo "Started cleaning BAM file"

# File name for cleaned bam
clean_bam="${sample}_${lane}_fixmate_sort_binfix_clean.bam"
clean_bam="${bam_folder}/${clean_bam}"

# Clean bam
java -Xmx"${java_xmx}" -jar "${picard}" CleanSam \
  INPUT="${binfix_bam}" \
  OUTPUT="${clean_bam}" \
 	VERBOSITY=ERROR \
  CREATE_INDEX=true \
  CREATE_MD5_FILE=true \
 	QUIET=true

# Remove sorted bam
rm -f "${binfix_bam}"

# Progress report
echo "Completed bam cleaning: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Validate bam ------- #
# exits if errors found (prints initial 100 errors by default)

# Progress report
echo "Started bam validation"

# Validate bam
java -Xmx"${java_xmx}" -jar "${picard}" ValidateSamFile \
  INPUT="${clean_bam}" \
  VERBOSITY=ERROR \
  QUIET=true \
  MODE=SUMMARY

# Progress report
echo "Completed bam validation: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Mark duplicates ------- #
# Note that duplicates are marked, but not removed.  
# At this stage the duplicates are marked to collect metrics only (e.g. flagstats).  
# The file with marked duplicates will be deleted. 
# The file w/o duplicate marking will be taken for downstream merging (the next step of the pipeline).  
# The duplicates will be marked again later, after merging all lines from the same library.
# This will allow acurate metrics collection at both steps.  
# Then the duplicates will be actually removed from the merged bams. 

# Progress report
echo "Started marking PCR duplicates"

# Mkdup bam name
mkdup_bam_file="${sample}_${lane}_fixmate_sort_binfix_clean_mkdup.bam"
mkdup_bam="${bam_folder}/${mkdup_bam_file}"

# Mkdup stats file name
mkdup_stats_file="${sample}_mkdup.txt"
mkdup_stats="${picard_mkdup_folder}/${mkdup_stats_file}"

# Process sample
java -Xmx"${java_xmx}" -jar "${picard}" MarkDuplicates \
  INPUT="${clean_bam}" \
  OUTPUT="${mkdup_bam}" \
  METRICS_FILE="${mkdup_stats}" \
  REMOVE_DUPLICATES=false \
  TMP_DIR="${picard_mkdup_folder}" \
  MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=1000 \
  CREATE_INDEX=true \
  VERBOSITY=ERROR \
  QUIET=true

# Notes about MarkDuplicates options:

# Mkdup writes many temporary files on disk (gigabaites).  
# This may generate error, if /tmp folder size is insufficient.  
# To avoid this error, an explicit address for tmp folder may be used. 

# Another parameter that may need to be controlled: the max num of 
# file handlers per process.  On AWS Linux ec2 instances it is set to 1024 (ulimit -n)
# Hence the MAX_FILE_HANDLES_FOR_READ_ENDS_MAP=1000

# Progress report
echo "Completed marking PCR duplicates: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Collect flagstat metrics ------- #

# Progress report
echo "Started collecting flagstat metrics"

# flagstats metrics file name
flagstats_file="${sample}_flagstat.txt"
flagstats="${flagstat_folder}/${flagstats_file}"

# Sort using samtools (later may be switched to picard SortSam)
${samtools} flagstat "${mkdup_bam}" > "${flagstats}"

# Progress report
echo "Completed collecting flagstat metrics: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Collect inserts sizes ------- #
# Requires R in $PATH

# Progress report
echo "Started collecting inserts sizes"

# Stats files names
inserts_stats="${picard_inserts_folder}/${sample}_insert_sizes.txt"
inserts_plot="${picard_inserts_folder}/${sample}_insert_sizes.pdf"

# Process sample
java -Xmx"${java_xmx}" -jar "${picard}" CollectInsertSizeMetrics \
  INPUT="${mkdup_bam}" \
  OUTPUT="${inserts_stats}" \
  HISTOGRAM_FILE="${inserts_plot}" \
  VERBOSITY=ERROR \
  QUIET=true #2> "${CollectInsertSizeMetrics.log}" ?

# Progress report (if run sequential)
echo "Completed collecting inserts size metrics: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Collect alignment summary metrics ------- #
# Use the same genome as for BWA index in alignment 

# Progress report
echo "Started collecting alignment summary metrics"

# Mkdup stats file names
alignment_metrics="${picard_alignment_folder}/${sample}_as_metrics.txt"

# Process sample (using default adapters list)
java -Xmx"${java_xmx}" -jar "${picard}" CollectAlignmentSummaryMetrics \
  INPUT="${mkdup_bam}" \
  OUTPUT="${alignment_metrics}" \
  REFERENCE_SEQUENCE="${ref_genome}" \
  VERBOSITY=ERROR \
  QUIET=true #2> "${CollectAlignmentSummaryMetrics.log}" ?

# Progress report (if run sequential)
echo "Completed collecting alignment summary metrics: $(date +%d%b%Y_%H:%M:%S)"
echo ""

# ------- Collect hybridisation selection metrics ------- #

# Progress report
echo "Started collecting hybridisation selection metrics"

# Stats file names
hs_metrics="${picard_hybridisation_folder}/${sample}_hs_metrics.txt"
hs_coverage="${picard_hybridisation_folder}/${sample}_hs_coverage.txt"

# Process sample (using b37 interval lists)
java -Xmx"${java_xmx}" -jar "${picard}" CalculateHsMetrics \
  BAIT_SET_NAME="${bait_set_name}" \
  BAIT_INTERVALS="${probes_intervals}" \
  TARGET_INTERVALS="${targets_intervals}" \
  REFERENCE_SEQUENCE="${ref_genome}" \
  INPUT="${mkdup_bam}" \
  OUTPUT="${hs_metrics}" \
  PER_TARGET_COVERAGE="${hs_coverage}" \
  VERBOSITY=ERROR \
  QUIET=true #2> "${CalculateHsMetrics.log}" ?

# Progress report (if run sequential)
echo "Completed collecting hybridisation selection metrics: $(date +%d%b%Y_%H:%M:%S)"
echo ""

#########################################################################################################
if [ "a" == "b" ]
then
#########################################################################################################

# ------- Qualimap ------- #

if [ "${run_qualimap}" == "yes" ] 
then

    # Progress report
    echo "Started qualimap"
    
    # Folder for sample
    qualimap_sample_folder="${qualimap_results_folder}/${sample}"
    mkdir -p "${qualimap_sample_folder}"
    
    # Variable to reset default memory settings for qualimap
    export JAVA_OPTS="-Xms1g -Xmx${java_xmx}"
    
    # Start qualimap
    qualimap_log="${qualimap_sample_folder}/${sample}.log"
    "${qualimap}" bamqc \
      -bam "${mkdup_bam}" \
      --paint-chromosome-limits \
      --genome-gc-distr HUMAN \
      --feature-file "${targets_bed_6}" \
      --outside-stats \
      -nt 14 \
      -outdir "${qualimap_sample_folder}" &> "${qualimap_log}"
    
    # Progress report
    echo "Completed qualimap: $(date +%d%b%Y_%H:%M:%S)"
    echo ""
    
elif [ "${run_qualimap}" == "no" ] 
then
    # Progress report
    echo "Omitted qualimap"
    echo ""
else
    # Error message
    echo "Wrong qualimap setting: ${run_qualimap}"
    echo "Should be yes or no"
    echo "Qualimap omitted"
    echo ""
fi

# ------- Samstat ------- #

if [ "${run_samstat}" == "yes" ] 
then

    # Progress report
    echo "Started samstat"
    
    # Run sumstat
    samstat_log="${samstat_results_folder}/${sample}_samstat.log"
    "${samstat}" "${mkdup_bam}" &> "${samstat_log}"
    
    # Move results to the designated folder
    samstat_source="${mkdup_bam}.samstat.html"
    samstat_target=$(basename "${mkdup_bam}.samstat.html")
    samstat_target="${samstat_results_folder}/${samstat_target}"
    mv -f "${samstat_source}" "${samstat_target}"
    
    # Progress report
    echo "Completed samstat: $(date +%d%b%Y_%H:%M:%S)"
    echo ""

elif [ "${run_samstat}" == "no" ] 
then
    # Progress report
    echo "Omitted samstat"
    echo ""
else
    # Error message
    echo "Wrong samstat setting: ${run_samstat}"
    echo "Should be yes or no"
    echo "Samstat omitted"
    echo ""
fi

# ------------------ Remove mkdupped bams -------------------- #

rm -f "${mkdup_bam}"
rm -f "${mkdup_bam}.md5"
rm -f "${mkdup_bam%.bam}.bai"

# Progress report
echo "Removed mkdupped bams"
echo ""

# Note:
# Pipeline performs duplication analysis for QC. However, if 
# several lanes will be run for the same library, the marking
# and removing PCR duplicates should be done AFTER merging files 
# from different lanes.  It is possible, however, to consider
# re-makdupping of merged mkdupped files. 

# -- Add sample to the lane's sample list (for merging step) -- #

bam_samples_file="${lane_folder}/samples.txt"

bam_file_name=$(basename "${rg_bam}")
bam_file_name="f03_bam/${bam_file_name}"
echo -e "${sample}\t${bam_file_name}" >> "${bam_samples_file}"

# Progress report
echo "Added sample to the bam list"
echo ""

#########################################################################################################
fi
#########################################################################################################

# ------------------- Update pipeline log  ------------------- #

echo "Completed ${sample}_${data_type}: $(date +%d%b%Y_%H:%M:%S)" >> "${pipeline_log}"
