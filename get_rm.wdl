
#########################

## get all sites from mutect VCF as well as filter status, AD, and DP ##

#########################

version 1.0

workflow MutectSites {
  meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
    File vcf_in
		String gatk_docker
    String sample_id
	}

  call GetRM {
    input:
      vcf_in = vcf_in,
      gatk_docker = gatk_docker,
      sample_id = sample_id
  }

  output {
  	File RM_sites = GetRM.txt_out
    File RM_summary = GetRM.summary_out
  }

}


task GetRM {

  input {
    File vcf_in
    String gatk_docker
    String sample_id
  }
  
  output {
    File txt_out = "~{sample_id}.txt"
    File summary_out = "~{sample_id}_summary.txt"
  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`
    bcftools query -f "%CHROM\t%POS\t%REF\t%ALT\t%FILTER\t[%AD\t%AF]\t%INFO/RMNM\t%INFO/RMCL\t%INFO/RMFAM\n" ~{vcf_in} \
    | awk -v sample_id=~{sample_id} '{print $0"\t"sample_id}' \
    > ~{sample_id}.txt

    echo -e "Pass_vars\tRMCL\tSAMPLE_ID" >> ~{sample_id}_summary.txt
    cat ~{sample_id}.txt | awk '{print $9"\t"$11}' | sort | uniq -c | awk '{print $1"\t"$2"\t"$3}' >> ~{sample_id}_summary.txt

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
