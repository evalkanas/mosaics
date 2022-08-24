
#########################

## Zip and index vcf file ##

#########################

version 1.0

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
  }
  
  output {
    File vcf_out = basename(vcf_in) + ".gz"
    File vcf_out_index = basename(vcf_in) + ".gz.tbi"

  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`

    bgzip ~{vcf_in} > ~{vcf_out}
    tabix -p vcf ~{vcf_out} 
  >>>
  runtime {
    docker: gatk_docker
    cpu: 1
    memory: "10 GiB"
    disks: "local-disk 30 HDD" 
    bootDiskSizeGb: 20
    preemptible: 3
    maxRetries: 1
  }

}
