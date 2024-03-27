
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
    File pass_vcf = Qc.pass_vcf
    File pass_vcf_idx = Qc.pass_vcf_index
    File pass_stats = Qc.pass_stats
    String pass_phrase = Qc.status
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
    File pass_vcf = "~{sample_id}_~{prefix}_pass.vcf.gz"
    File pass_vcf_index = "~{sample_id}_~{prefix}_pass.vcf.gz.tbi"
    File pass_stats = "~{sample_id}_~{prefix}_pass_stats.txt"
    String status=status
  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`

    #filter to pass variants
    bcftools view -f PASS ~{vcf_in} -Oz -o ~{sample_id}_~{prefix}_pass.vcf.gz
    tabix -p vcf ~{sample_id}_~{prefix}_pass.vcf.gz

    #generate variants per chr file
    echo -e "chr\t~{sample_id}" > ~{sample_id}_~{prefix}_pass_stats.txt
    bcftools index -s ~{sample_id}_~{prefix}_pass.vcf.gz | awk '{print $1"\t"$3}' >> ~{sample_id}_~{prefix}_pass_stats.txt

    #check if any chr has zero variants 
    status="Complete"
    #if any line has 0 variants, status = "Missing"
    while read chr, vars
    do if [[ $chr==0 ]]
    then status="Missing"
    fi
    done < ~{sample_id}_~{prefix}_pass_stats.txt
    echo $status


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
