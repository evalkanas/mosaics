
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
      file_in = vcf_in,
      docker = gatk_docker
  }

  output {
  	File vcf_out = ZipVcf.vcf_out
    File vcf_out_index = ZipVcf.vcf_out_index
  }

}


task ZipVcf {

  input {
    File file_in
    String docker
    RuntimeAttr? runtime_attr_override
  }

  Int num_cpu = 1
  Int mem_size_gb = 4
  Int vm_disk_size = 50

  RuntimeAttr default_attr = object { 
    cpu_cores: num_cpu, 
    mem_gb: mem_size_gb, 
    disk_gb: vm_disk_size,
    boot_disk_gb: 10,
    preemptible_tries: 3,
    max_retries: 1
  }
  RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])

  output {
    File vcf_out = file_in + ".gz"
    File vcf_out_index = file_in + ".gz.tbi"

  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`

    bgzip ~{file_in} > ~{vcf_out}
    tabix -p ~{vcf_out} 
  >>>
  runtime {
    docker: docker
    cpu: select_first([runtime_attr.cpu_cores, default_attr.cpu_cores])
    memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
    disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
    bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
    preemptible: select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
    maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
  }

}
