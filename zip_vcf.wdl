
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


  String prefix = basename(vcf_in, ".vcf")
  call ZipVcf {
    input:
      vcf_in = vcf_in,
      gatk_docker = gatk_docker,
      prefix = prefix
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
    String prefix
  }
  
  output {
    File vcf_out = "~{prefix}.vcf.gz"
    File vcf_out_index = "~{prefix}.vcf.gz.tbi"
  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`

    bcftools sort ~{vcf_in} -O z -o ~{prefix}.vcf.gz
    tabix -p vcf ~{prefix}.vcf.gz

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
