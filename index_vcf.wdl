
#########################

## Zip and index vcf file ##

#########################

version 1.0

workflow IndexVcf {
  meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
    File vcf_in
    String gatk_docker
	}

  call IdxVcf {
    input:
      vcf_in = vcf_in,
      gatk_docker = gatk_docker,
  }

  output {
    File vcf_index = IdxVcf.vcf_out_index
  }

}


task IdxVcf {

  input {
    File vcf_in
    String gatk_docker
  }
  
  output {
    File vcf_out_index = "~{vcf_in}.tbi"
  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`

    tabix -p vcf ~{vcf_in}

  >>>

  runtime {
    docker: gatk_docker
    cpu: 1
    memory: "8 GiB"
    disks: "local-disk 40 HDD" 
    bootDiskSizeGb: 20
    preemptible: 3
    maxRetries: 1
  }

}
