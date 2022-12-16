
#########################

## get all sites from mutect VCF as well as filter status, AD, and DP ##

#########################

version 1.0

workflow SubsetSites {
  meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
    File vcf_in
    File vcf_idx
		String gatk_docker
    String sample_id
    File bed
    String prefix
	}

  call GetSites {
    input:
      vcf_in = vcf_in,
      vcf_idx = vcf_idx,
      gatk_docker = gatk_docker,
      sample_id = sample_id,
      prefix = prefix,
      bed = bed
  }

  output {
  	File bed_filtered_vcf = GetSites.vcf_out
    File bed_filtered_idx = GetSites.vcf_index
  }

}


task GetSites {

  input {
    File vcf_in
    File vcf_idx
    String gatk_docker
    String sample_id
    File bed
    String prefix
  }
  
  output {
    File vcf_out = "~{sample_id}_~{prefix}.vcf.gz"
    File vcf_index = "~{sample_id}_~{prefix}.vcf.gz.tbi"
  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`
    #bcftools view -R ~{bed} ~{vcf_in} -Oz -o ~{sample_id}_~{prefix}.vcf.gz
    tabix -h -R ~{bed} ~{vcf_in} | bgzip > ~{sample_id}_~{prefix}.vcf.gz
    tabix -p vcf ~{sample_id}_~{prefix}.vcf.gz

  >>>

  runtime {
    docker: gatk_docker
    cpu: 1
    memory: "2 GiB"
    disks: "local-disk 20 HDD" 
    bootDiskSizeGb: 10
    preemptible: 3
    maxRetries: 1
  }

}
