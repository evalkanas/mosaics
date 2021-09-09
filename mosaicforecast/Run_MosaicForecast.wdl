
#########################

## Run Mosaic Forecast ##

#########################

version 1.0

# TODO: do I need the Structs wdl to run in Terra?
# import "Structs.wdl"


workflow runMF {

	 meta {
    author: "Elise Valkanas"
    email: "valkanas@broadinstitute.org"
  }

  input {
		
    Array[String] input_samples
    Array[File] mutect_vcfs
    Array[File] mutect_vcf_indexes
    Array[File] bam_or_crams
    Array[File] bam_or_cram_indexes

    File mutect_vcf
		String mf_docker
		#load the git repo into the docker
		File cram_dir
    

		File ref_fasta
		File ref_bigwig
		String seq_format #bam or cram
		#File input_positions #output of Mutect converted to work with mf 
		File mutect_bed_snv
		File mutect_bed_ins
		File mutect_bed_del
		String output_location #need to eventually change this so it will work with sample name somehow otherwise will get overwritten
		File rf_del # DEL random forest model
		File rf_ins # INS random forest model
		File rf_snv # SNV random forest model
		Int n_threads # 2 to start
		Int min_snp_dp # 20 to start
		String predict_model
	}


	output {
	  File 

	}

    call read_features as SNVfeatures {
      input:
      file_in = mutect_bed_snv
      bam_dir = cram_dir #input directory for the sample BAM/CRAM and index files
      ref_fasta = ref_fasta
      ref_bigwig = ref_bigwig
      n_threads = n_threads
      format = seq_format #bam or cram
      mf_docker = mf_docker
    }

    call read_features as INSfeatures {
      input:
      file_in = mutect_bed_ins
      bam_dir = cram_dir #input directory for the sample BAM/CRAM and index files
      ref_fasta = ref_fasta
      ref_bigwig = ref_bigwig
      n_threads = n_threads
      format = seq_format #bam or cram
      mf_docker = mf_docker
    }

    call read_features as DELfeatures {
      input:
      file_in = mutect_bed_del
      bam_dir = cram_dir #input directory for the sample BAM/CRAM and index files
      ref_fasta = ref_fasta
      ref_bigwig = ref_bigwig
      n_threads = n_threads
      format = seq_format #bam or cram
      mf_docker = mf_docker
    }

    call geno_predictions as SNVpredict {
      input:
      file_in = SNVfeatures.features_out
      model = rf_snv
      mf_docker = mf_docker
      model_type = predict_model
    }

    call geno_predictions as DELpredict {
      input:
      file_in = DELfeatures.features_out
      model = rf_del
      mf_docker = mf_docker
      model_type = predict_model
    }

    call geno_predictions as INSpredict {
      input:
      file_in = INSfeatures.features_out
      model = rf_ins
      mf_docker = mf_docker
      model_type = predict_model
	}

#TODO: work on what I want to phase

    call phasing {
      input: 
      bam_dir = cram_dir
      dir_out = output_location
      file_in = input_positions
      ref_fasta = ref_fasta
      ref_bigwig = ref_bigwig
      n_threads = n_threads #2
      min_snp_dp = min_snp_dp #20
      format = seq_format
	}

  output {
  	#output of whole workflow
  }

}

task phasing {
  input {

    File bam_dir
    File file_in 
    File dir_out #the code requires an output directory
    File ref_fasta 
    File ref_bigwig 
    Int n_threads 
    Int min_snp_dp
    String format
    String mf_docker
    RuntimeAttr? runtime_attr_override
  }

  # might need to tune these a little 
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

  String phase_out_name = dir_out + "/all.phasing"

  output {
    File phase_out = phase_out_name  
  }

  command <<<
	set -euo pipefail

	python /opt/MosaicForecast/Phase.py \
	  ~{bam_dir} \
	  ~{dir_out} \
	  ~{ref_fasta} \
	  ~{file_in} \ 
	  ~{min_snp_dp} \ 
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

task read_features {

  input {
    File file_in
    File bam_dir #input directory for the sample BAM/CRAM and index files
    File ref_fasta
    File ref_bigwig
    Int n_threads
    String format #bam or cram
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

  output {
    File features_out 

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
  	File predictions_out

  }

  command <<<
	set -euo pipefail

	python /opt/MosaicForecast/Prediction.R \
	  ~{file_in} \ #SNV or INS or DEL features file from extract read level features
	  ~{model} \
	  ~{model_type}\ #Phase or Refine
 	  ~{predictions_out} \

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

  bash /opt/Mutect_to_MF.sh \
    ~{file_in} \ #Mutect VCF output
    ~{sample_id} \
    ~{sample_mutect_bed_name}\ #Phase or Refine

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




