
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
		#do I need the git repo or is that included in the docker?
		File cram_dir

		File ref_fasta
		File ref_bigwig
		String seq_format
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

	}
	command <<<
	python 

	>>>
	runtime {

	}
	output {

	}


}

task read_features {

}

task geno_predictions {

}

