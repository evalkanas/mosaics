
#########################

## get all sites from mutect VCF as well as filter status, AD, and DP ##

#########################

version 1.0

import "Structs.wdl"

workflow CohortAF {
  meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
    File all_mutect_sites
    String gatk_docker
    String prefix
    Int cohort_N
    #deal with RuntimeAttr
	}

  call CalculateAF {
    input:
      all_mutect_sites = all_mutect_sites, 
      prefix = prefix, 
      gatk_docker = gatk_docker, 
      cohort_N = cohort_N
  }

  output {
    File all_cohort_af = CalculateAF.all_cohort_af
    File all_cohort_af_idx = CalculateAF.all_cohort_af_idx
    File pass_cohort_af = CalculateAF.pass_cohort_af
    File pass_cohort_af_idx = CalculateAF.pass_cohort_af_idx
    File temp_pass = CalculateAF.temp_pass
  }

}


task CalculateAF {
  input {
    File all_mutect_sites
    String prefix
    String gatk_docker
    Int cohort_N
    RuntimeAttr? runtime_attr_override
  }

  # when filtering/sorting/etc, memory usage will likely go up (much of the data will have to
  # be held in memory or disk while working, potentially in a form that takes up more space)
  Float input_size = size(all_mutect_sites, "GB")
  RuntimeAttr runtime_default = object {
    mem_gb: 80.0,
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

    N=~{cohort_N}

    #get AF files
    cut -f-4 ~{all_mutect_sites} | sort -V | uniq -c | grep -v "," | awk -v N="$N" '{print $2"\t"$3"\t"$4"\t"$5"\t"($1/(N*2))"\t"N}' > ~{prefix}_all_sites_af.tab
    bgzip ~{prefix}_all_sites_af.tab
    tabix -s 1 -b 2 -e 2 ~{prefix}_all_sites_af.tab.gz

    grep PASS ~{all_mutect_sites} > ~{prefix}_temp_pass.tab
    cut -f-4 ~{prefix}_temp_pass.tab | sort -V | uniq -c | awk -v N="$N" '{print $2"\t"$3"\t"$4"\t"$5"\t"($1/(N*2))}' > ~{prefix}_pass_sites_af.tab
    bgzip ~{prefix}_pass_sites_af.tab
    tabix -s 1 -b 2 -e 2 ~{prefix}_pass_sites_af.tab.gz 

  >>>

  output {
    File all_cohort_af = "~{prefix}_all_sites_af.tab.gz"
    File all_cohort_af_idx = "~{prefix}_all_sites_af.tab.gz.tbi"
    File pass_cohort_af = "~{prefix}_pass_sites_af.tab.gz"
    File pass_cohort_af_idx = "~{prefix}_pass_sites_af.tab.gz.tbi"
    File temp_pass = "~{prefix}_temp_pass.tab"
  }
}

