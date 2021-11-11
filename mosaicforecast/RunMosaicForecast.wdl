
#########################

## Run Mosaic Forecast ##

#########################

version 1.0

import "Structs.wdl"


workflow runMosaicForecast {
  meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
		
    Array[String] input_samples
    Array[File] mutect_vcfs
    Array[File] mutect_vcf_indexes
    Array[File] bam_or_crams # dir containing sample BAM/CRAM and idex file 
    Array[File]? bam_or_cram_indexes

		String mf_docker
    

		File ref_fasta
		File ref_bigwig
		String seq_format #bam or cram 
		File rf_model #random forest model
		Int n_threads # 2 to start
		Int min_snp_dp # 20 to start
		String predict_model
    String all_predictions #name of output file with genotype predictions
	}

  scatter (i in range(length(mutect_vcfs)))) {
    call mutect2mf {
      input:
        file_in = mutect_vcfs[i],
        sample_id = input_samples[i],
        mf_docker = mf_docker
    }

    call read_features {
      input:
        file_in = mutect2mf.sample_mutect_bed, 
        bam_dir = bam_or_crams[i], #input directory for the sample BAM/CRAM and index files
        ref_fasta = ref_fasta,
        ref_bigwig = ref_bigwig,
        n_threads = n_threads,
        format = seq_format, #bam or cram
        mf_docker = mf_docker,
        sample_id = input_samples[i]
    }
  }

    #combine read features results for all samples

  call gather_features {

    input: 
      feature_files = read_features.features_out

  }

  call geno_predictions {
    input:
      file_in = gather_features.all_features,
      model = rf_model,
      mf_docker = mf_docker,
      model_type = predict_model,
      predictions_name = all_predictions
  }

  output {
  	File final_predictions = geno_predictions.predictions_out
  }

}


task read_features {

  input {
    File file_in
    File bam_dir #input directory for the sample BAM/CRAM and index files
    File ref_fasta
    File ref_bigwig
    Int n_threads
    String format #bam or cram
    String mf_docker
    String sample_id 
    RuntimeAttr? runtime_attr_override
  }

  Int num_cpu = 1
  Int mem_size_gb = 4
  Int vm_disk_size = 50

  RuntimeAttr default_attr = object { 
    cpu_cores: num_cpu, 
    mem_gb: mem_size_gb, 
    disk_gb: vm_disk_size,
    boot_disk_gb: 10,
    preemptible_tries: 3,
    max_retries: 1
  }
  RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])

  output {
    File features_out = sample_id + ".features"

  }

  command <<<
    set -euo pipefail

    python /opt/MosaicForecast/ReadLevel_Features_extraction.py \
	  ~{file_in} \ #filtered SNV or INS or DEL bed file from Mutect
	  ~{features_out} \
	  ~{bam_dir} \
	  ~{ref_fasta}  \
	  ~{ref_bigwig} \
	  ~{n_threads} \
	  ~{format}
  >>>
  runtime {
    docker: mf_docker
    cpu: select_first([runtime_attr.cpu_cores, default_attr.cpu_cores])
    memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
    disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
    bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
    preemptible: select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
    maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
  }

}

task geno_predictions {
  input {
  	File file_in
  	File model
  	String model_type #Phase or Refine
    String mf_docker
    String predictions_name
    RuntimeAttr? runtime_attr_override
  }

  Int num_cpu = 1
  Int mem_size_gb = 4
  Int vm_disk_size = 50

  RuntimeAttr default_attr = object { 
    cpu_cores: num_cpu, 
    mem_gb: mem_size_gb, 
    disk_gb: vm_disk_size,
    boot_disk_gb: 10,
    preemptible_tries: 3,
    max_retries: 1
  }
  RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])

  output {
  	File predictions_out = predictions_name

  }

  command <<<
	set -euo pipefail

	python /opt/MosaicForecast/Prediction.R \
	  ~{file_in} \ #SNV or INS or DEL features file from extract read level features
	  ~{model} \
	  ~{model_type}\ #Phase or Refine
 	  ~{predictions_out} 

  >>>
  runtime {
    docker: mf_docker
    cpu: select_first([runtime_attr.cpu_cores, default_attr.cpu_cores])
    memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
    disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
    bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
    preemptible: select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
    maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
  }


}


task mutect2mf {
  input {
    File file_in #mutect vcf
    String sample_id
    String mf_docker
    RuntimeAttr? runtime_attr_override
  }

  Int num_cpu = 1
  Int mem_size_gb = 4
  Int vm_disk_size = 50

  RuntimeAttr default_attr = object { 
    cpu_cores: num_cpu, 
    mem_gb: mem_size_gb, 
    disk_gb: vm_disk_size,
    boot_disk_gb: 10,
    preemptible_tries: 3,
    max_retries: 1
  }
  RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])
  
  String sample_mutect_bed_name = sample_id + "_mutect.bed"


  output {
    File sample_mutect_bed = sample_mutect_bed_name #converted mutect vcf to bed

  }

  command <<<
  set -euo pipefail
   
  # TODO add Mutect_to_MF to Dockerfile

  bash /opt/mutect_to_mosaic_forecast.sh \ 
    ~{file_in} \ #Mutect VCF output
    ~{sample_id} \
    ~{sample_mutect_bed_name} #Output file name

  >>>
  runtime {
    docker: mf_docker
    cpu: select_first([runtime_attr.cpu_cores, default_attr.cpu_cores])
    memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
    disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
    bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
    preemptible: select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
    maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
  }

# TODO add task gather per sample

task gather_features {
  input {
    Array[File] feature_files
  }

  command <<<
  set -euo pipefail

  #combine individual sample features file into one large file 
  cat <(cat ~{feature_files}|grep '^id' |head -1)  <(cat ~{feature_files}|grep -v '^id') > {output}

  >>>

  output {
    File all_features = "allsamples.features"
  }
}
