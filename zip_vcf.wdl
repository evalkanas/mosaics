
#########################

## Zip and index vcf file ##

#########################

version 1.0

import "Structs.wdl"


workflow CompressVcf {
  meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
    File vcf_in
		String gatk_docker
	}


  call ZipVcf {
    input:
      vcf_in = vcf_in,
      gatk_docker = gatk_docker
  }

  output {
  	File zip_vcf = ZipVcf.vcf_out
    File zip_vcf_index = ZipVcf.vcf_out_index
  }

}


task ZipVcf {

  input {
    File vcf_in
    String gatk_docker
    RuntimeAttr? runtime_attr_override
  }
  

  RuntimeAttr default_attr = object { 
    cpu_cores: 1, 
    mem_gb: 4, 
    disk_gb: 50,
    boot_disk_gb: 10,
    preemptible_tries: 3,
    max_retries: 1
  }
  RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])

  output {
    File vcf_out = vcf_in + ".gz"
    File vcf_out_index = vcf_in + ".gz.tbi"

  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`

    bgzip ~{vcf_in} > ~{vcf_out}
    tabix -p vcf ~{vcf_out} 
  >>>
  runtime {
    docker: gatk_docker
    cpu: select_first([runtime_attr.cpu_cores, default_attr.cpu_cores])
    memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
    disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
    bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
    preemptible: select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
    maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
  }

}
