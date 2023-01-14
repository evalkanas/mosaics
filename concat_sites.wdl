
#########################

## get all sites from mutect VCF as well as filter status, AD, and DP ##

#########################

version 1.0

import "Structs.wdl"

workflow MutectSummary {
  meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
    Array[File] sample_mutect_sites_files
    Array[File] sample_summary_stats_files
    String gatk_docker
    String prefix
    #deal with RuntimeAttr
	}

  call ConcatSites {
    input:
      sample_mutect_sites_files = sample_mutect_sites_files,
      sample_summary_stats_files = sample_summary_stats_files, 
      prefix = prefix, 
      gatk_docker = gatk_docker
  }

  output {
    File mutect_sites = ConcatSites.unique_mutect_sites
    File mutect_summary = ConcatSites.mutect_sample_summary
    File all_mutect_site_info = ConcatSites.all_mutect_sites
  }

}


task ConcatSites {
  input {
    Array[File] sample_mutect_sites_files
    Array[File] sample_summary_stats_files
    String prefix
    String gatk_docker
    RuntimeAttr? runtime_attr_override
  }

  String output_sites_file="~{prefix}_vcf_unique_sites.txt"
  String output_summ_file="~{prefix}_sample_summary.txt"
  String output_all_sites_file="~{prefix}_vcf_all_sites.txt"

  # when filtering/sorting/etc, memory usage will likely go up (much of the data will have to
  # be held in memory or disk while working, potentially in a form that takes up more space)
  Float input_size = size(sample_mutect_sites_files, "GB")
  RuntimeAttr runtime_default = object {
    mem_gb: 2.0,
    disk_gb: ceil(10.0 + input_size * 7.0),
    cpu_cores: 1,
    preemptible_tries: 3,
    max_retries: 1,
    boot_disk_gb: 10
  }
  RuntimeAttr runtime_override = select_first([runtime_attr_override, runtime_default])
  runtime {
    memory: select_first([runtime_override.mem_gb, runtime_default.mem_gb]) + " GB"
    disks: "local-disk " + select_first([runtime_override.disk_gb, runtime_default.disk_gb]) + " HDD"
    cpu: select_first([runtime_override.cpu_cores, runtime_default.cpu_cores])
    preemptible: select_first([runtime_override.preemptible_tries, runtime_default.preemptible_tries])
    maxRetries: select_first([runtime_override.max_retries, runtime_default.max_retries])
    docker: gatk_docker
    bootDiskSizeGb: select_first([runtime_override.boot_disk_gb, runtime_default.boot_disk_gb])
  }

  command <<<
    set -eux

    # no more early stopping
    set -o pipefail

    while read SPLIT; do
      cat $SPLIT
    done < ~{write_lines(sample_mutect_sites_files)} \
      | awk '{print $1"\t"$2}' \
      | sort -u \
      > ~{output_sites_file}

    while read SPLIT; do
      cat $SPLIT
    done < ~{write_lines(sample_mutect_sites_files)} > ~{output_all_sites_file}

    echo -e "SAMPLE\tPZM\tGERMLINE\tFILTERED\tANY_WEAK_EVIDENCE\tWEAK_EVIDENCE_ONLY\tWEAK_EVIDENCE_AND_OTHER" > ~{output_summ_file} 

    while read SAMP; do
      head -n 1 $SAMP
#      cat $SAMP 
    done < ~{write_lines(sample_summary_stats_files)} \
    >> ~{output_summ_file} 

  >>>

  output {
    File all_mutect_sites = output_all_sites_file
    File unique_mutect_sites = output_sites_file
    File mutect_sample_summary = output_summ_file
  }
}

