
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
    File lcr
    File wes
    File pass_af
    File pass_af_idx
    File all_af
    File all_af_idx
    File simplerepeat
    File segdup
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
      gc_bed_idx = gc_bed_idx, 
      lcr = lcr,
      wes = wes,
      pass_af = pass_af,
      pass_af_idx =pass_af_idx,
      all_af = all_af,
      all_af_idx = all_af_idx,
      simplerepeat = simplerepeat, 
      segdup = segdup
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
    File lcr
    File wes
    File pass_af
    File pass_af_idx
    File all_af
    File all_af_idx
    File simplerepeat
    File segdup
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
    bcftools annotate \
      -a ~{bed} \
      -c CHROM,FROM,TO,RMNM,RMCL,RMFAM \
      -h ~{bed_header} \
      -l RMNM:append,RMCL:append,RMFAM:append \
      ~{vcf_in} -Ou \
        | bcftools annotate \
        -a ~{gc_bed} \
        -c CHROM,FROM,TO,GC  \
        -l GC:append -Ou \
          | bcftools annotate -a ~{wes} \
          -c CHROM,FROM,TO,-,-,- -m +WESREG \
          | bcftools annotate -a ~{simplerepeat} \
          -c CHROM,FROM,TO,-,-,- -m +SIMPLEREP \
          | bcftools annotate -a ~{segdup} \
          -c CHROM,FROM,TO,-,-,- -m +SEGDUP \
          | bcftools annotate -a ~{lcr} \
          -c CHROM,FROM,TO,-,-,- -m +LCR \
          | bcftools annotate -a ~{all_af} \
          -c CHROM,POS,REF,ALT,all_cohort_ac,all_cohort_af,cohort_n \
          | bcftools annotate -a ~{pass_af} \
          -c CHROM,POS,REF,ALT,pass_cohort_ac,pass_cohort_af \
          -Oz -o ~{sample_id}_~{prefix}.vcf.gz

    tabix -p vcf ~{sample_id}_~{prefix}.vcf.gz

    #filter to pass variants
    bcftools view -f PASS ~{sample_id}_~{prefix}.vcf.gz -Oz -o ~{sample_id}_~{prefix}_pre_pass.vcf.gz
    tabix -p vcf ~{sample_id}_~{prefix}_pre_pass.vcf.gz

    #remove mnp and large indels 
    bcftools filter -e 'strlen(REF)==2 && strlen(ALT)==2' ~{sample_id}_~{prefix}_pre_pass.vcf.gz\
    | bcftools filter -e 'strlen(REF)>50'\
    | bcftools filter -e 'strlen(ALT)>50'  -Oz -o ~{sample_id}_~{prefix}_pass.vcf.gz

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
