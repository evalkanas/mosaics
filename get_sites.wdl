
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

  call GetSites {
    input:
      vcf_in = vcf_in,
      gatk_docker = gatk_docker,
      sample_id = sample_id
  }

  output {
  	File mutect_sites = GetSites.txt_out
    File mutect_summary = GetSites.summary_out
  }

}


task GetSites {

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
    bcftools query -f "%CHROM\t%POS\t%REF\t%ALT\t%FILTER\t[%AD\t%AF]\n" ~{vcf_in} > ~{sample_id}.txt
    #| awk -v sample_id=~{sample_id} '{print $0"\t"sample_id}' \
    #> ~{sample_id}.txt

    vars=$(wc -l ~{sample_id}.txt | awk '{print $1}')
    germ=$(awk '{ if ($5 == "germline") print $5}' ~{sample_id}.txt | wc -l)
    pass=$(grep -c "PASS" ~{sample_id}.txt

    filter=$(($vars-$pass-$germ))

    #echo number of PZM, germline, and filtered variants identified by mutect for this sample
    echo ~{sample_id}"\t"${pass}"\t"${germ}"\t"${filter}"\n" > ~{sample_id}_summary.txt

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
