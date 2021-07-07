
#########################

## Run Mosaic Forecast ##

#########################

version 1.0

# TODO: do I need the Structs wdl to run in Terra?
# import "Structs.wdl"


workflow runMF {

	input {
		File mutect_vcf
		String mf_docker
		#load the git repo into the docker
		File cram_dir

		File ref_fasta
		File ref_bigwig
		String seq_format
		File input_positions #output of Mutect converted to work with mf
		String output_location #need to eventually change this so it will work with sample name somehow otherwise will get overwritten
	}

	meta {
		author: "Elise Valkanas"
		email: "valkanas@broadinstitute.org"
	}
	output {

	}

	call phasing {
		input: 
		bam_dir = cram_dir
		dir_out = output_location
		file_in = input_positions
		ref_fasta = ref_fasta
		ref_bigwig = ref_bigwig
		n_threads = 2
		min_snp_dp = 20
		format = seq_format
	}

	call read_features {

	}

	call geno_predictions as SNP.predict {

	}

	call geno_predictions as DEL.predict {

	}

	call geno_predictions as INS.predict {

	}

}

task phasing {
  input {
  	String dir_out
  	String phase_out_name = dir_out + "/all.phasing"
	File bam_dir
	File file_in 
	File ref_fasta 
	File ref_bigwig 
	String n_threads 
	String min_snp_dp
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
  output {
  	File phase_out = phase_out_name
  }


}

task read_features {

  input {

  }
  command <<<
	set -euo pipefail

	python /opt/MosaicForecast/ReadLevel_Features_extraction.py \
	  ~{file_in} \ 
	  ~{features_in} \
	  ~{ref_fasta}  \
	  ~{ref_bigwig} \
	  ~{n_threads} \
	  ~{format}
  >>>
  runtime {

  }
  output {
      

  }

}

task geno_predictions {

}

