
#########################

## remove sites from a VCF that are in an exclusion list provided as a bed file

#########################

version 1.0

workflow ExcludeSites {
  meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
    File vcf_in
    File exclusion_bed
    File exclusion_idx
		String gatk_docker
    String sample_id
	}

  call RemoveSites {
    input:
      vcf_in = vcf_in,
      exclusion_bed = exclusion_bed,
      exclusion_idx = exclusion_idx,
      gatk_docker = gatk_docker,
      sample_id = sample_id
  }

  output {
  	File mutect_sites = RemoveSites.vcf_out
    File mutect_summary = RemoveSites.vcf_out_idx
  }

}


task RemoveSites {

  input {
    File vcf_in
    File exclusion_bed
    File exclusion_idx
    String gatk_docker
    String sample_id
  }
  
  output {
    File vcf_out = "~{sample_id}_excluded.vcf.gz"
    File vcf_out_idx = "~{sample_id}_excluded.vcf.gz.tbi"
  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`

    bcftools view -T ^exclusion_bed vcf_in -Oz -o vcf_out
    tabix -p vcf vcf_out


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
