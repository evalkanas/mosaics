
#########################

## Annotate mutect VCF with Repeat Masker and GC content bed files ##

#########################

version 1.0

workflow CountSites {
  meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
    File vcf_in
    File vcf_idx
    String gatk_docker
    String sample_id
    String prefix
	}

  call Qc {
    input:
      vcf_in = vcf_in,
      vcf_idx = vcf_idx,
      gatk_docker = gatk_docker,
      sample_id = sample_id,
      prefix = prefix
  }

  output {
    File filtered_vcf = Qc.filtered_vcf
    File filtered_vcf_idx = Qc.filtered_vcf_index
    File stats = Qc.pass_stats
    String variant_count = Qc.vars
  }

}


task Qc {

  input {
    File vcf_in
    File vcf_idx
    String gatk_docker
    String sample_id
    String prefix
  }
  
  output {
    File filtered_vcf = "~{sample_id}_~{prefix}_pass.vcf.gz"
    File filtered_vcf_index = "~{sample_id}_~{prefix}_pass.vcf.gz.tbi"
    File pass_stats = "~{sample_id}_~{prefix}_pass_stats.txt"
    String vars = read_lines(stdout())[0]
  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`

    #filter to variants that meet RF GT!=0/0
    bcftools filter ~{vcf_in} -i 'GT!="0/0" && AF<0.373 && FMT/DP > 5' -Oz -o ~{sample_id}_~{prefix}_pass.vcf.gz
    tabix -p vcf ~{sample_id}_~{prefix}_pass.vcf.gz

    #generate variants per chr file
    echo -e "chr\tvariants\tsample_id" > ~{sample_id}_~{prefix}_pass_stats.txt
    bcftools index -s ~{sample_id}_~{prefix}_pass.vcf.gz | awk -v sample_id=~{sample_id} '{print $1"\t"$3"\t"sample_id}' >> ~{sample_id}_~{prefix}_pass_stats.txt


    #check if any chr has zero variants 
    vars=$(bcftools index -n ~{sample_id}_~{prefix}_pass.vcf.gz )
    echo $vars


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
