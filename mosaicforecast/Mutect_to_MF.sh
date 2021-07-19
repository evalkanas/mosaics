### Code to convert Mutect vcf output to input for MosaicForecast. Adapted from MosaicForecast Snakemake file (https://github.com/parklab/MosaicForecast/blob/master/Snakemake/Snakefile)

mutect_vcf = $1 # mutect VCF filtered with PON and gzipped
sample_name = $2
output = $3

#take in single sample VCF output by Mutect and convert to a bed file for that individual and produces a bed file with 9 cols: chr, start, stop, ref, alt, sample_id, AD_ref, AD_alt, AF (allele fraction)
#MT2_initial_filter in snakefile

cat <(zcat $mutect_vcf |grep -v '^#'| grep -v panel | grep -v PON | grep -v str_contraction | grep -v multiallelic | grep -v t_lod | gawk '{{match($0,/;POPAF=([0-9\.\-e]+);/,arr); if(arr[1]!~/-/ && arr[1]>4){{print $0}}}}' | cut -f1,2,4,5,10 | sed 's/:/\t/g'|sed 's/,/\t/g' | awk '$8>=0.03 && $8<0.4'| grep -v "0|1") <(zcat $mutect_vcf | grep -v '^#' | grep -v panel | grep -v PON|grep -v str_contraction|grep -v multiallelic|grep -v t_lod | gawk '{{match($0,/;POPAF=([0-9\.\-e]+);/,arr); if(arr[1]!~/-/ && arr[1]>4){{print $0}}}}'| cut -f1,2,4,5,10 | sed 's/:/\t/g' | sed 's/,/\t/g' | awk '$8>=0.02 && $8<0.4' | grep "0|1") | cut -f1-4,6-8 | awk -v sample_name=$sample_name '{{OFS="\t";print $1,$2-1,$2,$3,$4,sample_name,$5,$6,$7}}' > $output



# rule repeat_filter
# filters out seg dup regions


# rule annovar_formatter
# not sure what this does, but presumably annotates with some annovar databases


# rule MAF0_extraction_SNV:
# pulls out SNVs

# rule MAF0_extraction_INS

# rule MAF0_extraction_DEL

