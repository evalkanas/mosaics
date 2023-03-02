
#########################

## Annotate mutect VCF with Repeat Masker and GC content bed files ##

#########################

version 1.0

workflow AnnoSites {
  meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
    File vcf_in
    File vcf_idx
    String gatk_docker
    String sample_id
    File bed #bgzipped and indexed 
    File bed_idx
    File gc_bed
    File gc_bed_idx
    String prefix
    File bed_header #header with info for both bed files to add to output VCF
	}

  call Anno {
    input:
      vcf_in = vcf_in,
      vcf_idx = vcf_idx,
      gatk_docker = gatk_docker,
      sample_id = sample_id,
      prefix = prefix,
      bed = bed,
      bed_idx = bed_idx,
      bed_header = bed_header,
      gc_bed = gc_bed, 
      gc_bed_idx = gc_bed_idx
  }

  output {
    File anno_vcf = Anno.vcf_out
    File anno_vcf_idx = Anno.vcf_index
    File anno_pass_vcf = Anno.pass_vcf
    File anno_pass_vcf_idx = Anno.pass_vcf_index

  }

}


task Anno {

  input {
    File vcf_in
    File vcf_idx
    String gatk_docker
    String sample_id
    File bed
    File bed_idx
    File gc_bed
    File gc_bed_idx
    String prefix
    File bed_header
  }
  
  output {
    File vcf_out = "~{sample_id}_~{prefix}.vcf.gz"
    File vcf_index = "~{sample_id}_~{prefix}.vcf.gz.tbi"
    File pass_vcf = "~{sample_id}_~{prefix}_pass.vcf.gz"
    File pass_vcf_index = "~{sample_id}_~{prefix}_pass.vcf.gz.tbi"
  }

  command <<<
    set -euo pipefail

    export GCS_OAUTH_TOKEN=`gcloud auth application-default print-access-token`

    #annotate with bed file 
    #bcftools view -R ~{bed} ~{vcf_in} -Oz -o ~{sample_id}_~{prefix}.vcf.gz
    bcftools annotate -a ~{bed} -c CHROM,FROM,TO,RMNM,RMCL,RMFAM -h ~{bed_header} -l RMNM:append,RMCL:append,RMFAM:append \
    ~{vcf_in} -Oz -o ~{sample_id}_rm.vcf.gz | bcftools annotate -a {gc_bed}

    bcftools annotate -a {gc_bed} -c CHROM,FROM,TO,GC  -l GC:append \
    ~{sample_id}_rm.vcf.gz -Oz -o ~{sample_id}_~{prefix}.vcf.gz

    tabix -p vcf ~{sample_id}_~{prefix}.vcf.gz

    #filter to pass variants
    bcftools view -f PASS ~{sample_id}_~{prefix}.vcf.gz -Oz -o ~{sample_id}_~{prefix}_pass.vcf.gz

    tabix -p vcf ~{sample_id}_~{prefix}_pass.vcf.gz

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
