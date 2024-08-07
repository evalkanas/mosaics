
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
    File nomulti_vcf = Qc.nomulti_vcf
    File nomulti_vcf_idx = Qc.nomulti_vcf_index
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
    File nomulti_vcf = "~{sample_id}_~{prefix}_nomulti.vcf.gz"
    File nomulti_vcf_index = "~{sample_id}_~{prefix}_nomulti.vcf.gz.tbi"
    File pass_stats = "~{sample_id}_~{prefix}_pass_stats.txt"
    String status = read_lines(stdout())[0]
  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`

    #filter to pass variants
    bcftools view -f PASS ~{vcf_in} -Oz -o ~{sample_id}_~{prefix}_pass.vcf.gz
    tabix -p vcf ~{sample_id}_~{prefix}_pass.vcf.gz

    #generate variants per chr file
    echo -e "chr\tvariants\tsample_id" > ~{sample_id}_~{prefix}_pass_stats.txt
    bcftools index -s ~{sample_id}_~{prefix}_pass.vcf.gz | awk -v sample_id=~{sample_id} '{print $1"\t"$3"\t"sample_id}' >> ~{sample_id}_~{prefix}_pass_stats.txt

    #sum=`awk '{SUM+=$2}END{print SUM}' ~{sample_id}_~{prefix}_pass_stats.txt
    #echo -e "sum\t"${sum}"\t"~{sample_id} >> ~{sample_id}_~{prefix}_pass_stats.txt


    rm ~{sample_id}_~{prefix}_pass.vcf.gz*

    #check if any chr has zero variants 
    status="Complete"
    #if any line has 0 variants, status = "Missing"
    while read chr, vars
    do if [[ $chr==0 ]]
    then status="Missing"
    fi
    done < ~{sample_id}_~{prefix}_pass_stats.txt
    echo $status

    #no multiallelics file for annotation: 
    bcftools view -e'FILTER~"multiallelic"' ~{vcf_in} -Oz -o ~{sample_id}_~{prefix}_nomulti.vcf.gz
    tabix -p vcf ~{sample_id}_~{prefix}_nomulti.vcf.gz




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
