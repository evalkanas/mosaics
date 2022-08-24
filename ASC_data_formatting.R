library(ggplot2)
library(dplyr) 
library(tidyr)
library(readxl)

options(stringsAsFactors = F)

setwd("/Users/valkanas/Dropbox (HMS)/Talk_lab/mosaics/ASD_data/")

nygc_ped <- read.table("../../sfari/10065_66_SSC.ped", header=F, 
                       col.names = c("FamilyID", "WGS_ID", "Father_WGS_ID", "Mother_WGS_ID", 
                                     "final_ped_sex", "ped_aff"))

nygc_map <- read.csv("../../sfari/nygc_sfari_id_map.csv", header=T) %>%
  mutate(SFARI=SFARI_ID) %>%
  separate(SFARI, c("family_id", "role"), sep="[.]") %>%
  mutate(relation=ifelse(role=="p1", "proband", 
                    ifelse(role=="s1" | role=="s2", "sibling",
                           ifelse(role=="mo", "mother",
                                  ifelse(role=="fa", "father", "error"))))) %>%
  select(-role) %>%
  rename("entity:sample_id"="Repository_Id") %>%
  rename(participant_id=SFARI_ID) %>% 
  mutate(family_id=as.integer(family_id))

ASC_ped <- read.table("../../sfari/ASC_WGS_WES_6448.ped", 
                           header=F, col.names = c("FamilyID", "WGS_ID", "Father_WGS_ID", "Mother_WGS_ID", 
                                                   "final_ped_sex", "ped_aff"))
ASC_data <- read.delim("master_validation_short_hg38_wes_wgs_map_confirmed_rel.txt", sep="\t", header=T) %>% 
  #  filter(confirmed_wes_wgs_rel=="CONFIRMED") %>%
  select("family_id", "participant_id", "WGS_ID", "confirmed_wes_wgs_rel", "wes_id", "relation") %>%
  distinct() %>%
  rename("entity:sample_id"=WGS_ID) 

ASC_families <- ASC_data %>% select("family_id") %>% unlist()
 

CCDG_manifest <- read.table("CCDG_Freeze2_External_Crams_manifest.txt", header=F, sep="\t", 
                            col.names = c("size", "unit", "date", "file")) %>%
  mutate(type=ifelse(substr(file,nchar(file)-3,nchar(file))=="crai","cram_index","cram")) %>%
  mutate(new=file) %>%
  separate(new, c("path", "seq_id"), sep="ssc/") %>% 
  separate(seq_id, c("WGS_ID", "files", "ext", "ext2")) %>%
  select("WGS_ID", "file", "type") %>%
  pivot_wider(id_cols=WGS_ID, names_from = type, values_from = file)

CCDG_seq <- read.delim("CCDG_WGS_metadata_terra.tsv", sep = "\t", header=T) %>% 
  rename("sequencing_id"="entity.sequencing_id")

CCDG_seq_full <- full_join(CCDG_seq, CCDG_manifest)

CCDG_subject <- read.delim("../Mutect/Terra/CCDG_subject_table.tsv", header=T, sep="\t") %>%
  select("entity.subject_id", "family_id":"sex") %>%
  rename("WGS_ID"="entity.subject_id")

CCDG_all <- full_join(CCDG_seq_full, CCDG_subject)

samples_table <- CCDG_all %>% filter(family_id %in% ASC_families) %>% 
  rename("entity:sample_id"="WGS_ID") %>%
  left_join(nygc_map) %>% 
  select("entity:sample_id", "cram", "cram_index","family_id", "participant_id", 
         "sequencing_id":"relation") %>% 
  left_join(ASC_data)

particpants_table <- samples_table %>%
    rename("entity:participant_id"="participant_id") %>%
    select("entity:participant_id", "family_id", "relation", "mother_id", "father_id", "race_ethnicity")

samples_table <- samples_table %>% 
  select(-"mother_id", -"father_id", -"race_ethnicity")

write.table(samples_table, "terra_1279_samples.tsv", row.names = F, quote = F, sep="\t")
write.table(particpants_table, "terra_1279_participants.tsv", row.names = F, quote = F, sep="\t")

unrel_sibs <-  CCDG_all %>% filter(!(family_id %in% ASC_families))  %>% 
  rename("entity:sample_id"="WGS_ID") %>%
  left_join(nygc_map) %>% 
  rename("entity:pon_id"="entity:sample_id") %>%
  select("entity:pon_id", "cram", "cram_index","family_id", "participant_id", "sex", "relation", 
         "mother_id", "father_id", "race_ethnicity") %>%
  filter(relation=="sibling")

write.table(unrel_sibs, "terra_1672_pon.tsv", row.names = F, quote = F, sep="\t")

## limit pub data to samples we have WGS for ###
validated_map <- read.delim(file="master_validation_short_hg38_wes_wgs_map_confirmed_rel.txt", 
                            sep="\t", na.strings=".") %>%
  select(family_id:OROAK_RESOLUTION, relation)
seq_samples <- unlist(samples_table$participant_id)
WGS_sites <- validated_map %>% filter(participant_id %in% seq_samples)


## How many samples in Dou pub that are not represented above ##
dou <- read_xlsx("Dou_2017_validation.xlsx", sheet=1,  
                 col_names = T, 
                 col_types = c("numeric", "text","text", "numeric","numeric", "text","text","text", "text","text","text", "text","text","text", "text","text","text" )) %>%
  select("family_id", "SFARI_ID", "chr", "hg38_pos","ref", "alt", "DOU_RESOLUTION","relation")%>%
  rename(participant_id=SFARI_ID) %>%
  filter(family_id != 13904) #remove duo only 

#Make new validation sheet
new_validated <- full_join(dou, validated_map) %>% 
  mutate(ANY = ifelse(!is.na(DOU_RESOLUTION), DOU_RESOLUTION,
                      ifelse(!is.na(LIM_RESOLUTION), LIM_RESOLUTION,
                             ifelse(!is.na(FREED_RESOLUTION),FREED_RESOLUTION,
                                    ifelse(!is.na(OROAK_RESOLUTION),OROAK_RESOLUTION,"ERR"))))) %>%
  select("family_id":"alt","ANY", "DOU_RESOLUTION","LIM_RESOLUTION":"OROAK_RESOLUTION","relation")

setwd("/Users/valkanas/Dropbox (HMS)/Talk_lab/sfari/")


map_nygc <- read.table("nygc_sfari_id_map_3332_sib_pro.txt", header=F, 
                       col.names = c("NYGC_ID", "WGS_ID"), sep="\t")

map_nygc <- read.table("nygc_sfari_id_map.txt", header=T, sep="\t") %>% 
  rename(WGS_ID = Repository_Id) %>% rename(NYGC_ID = SFARI_ID)

map_rel <- read.table("ASC_WGS_WESvcf_sample_map.txt", header=T)

map_SSCID <- full_join(map_nygc, map_rel) %>%
  rename(participant_id=NYGC_ID)

new_validated_map <- left_join(new_validated, map_SSCID) %>% 
  mutate(., confirmed_wes_wgs_rel = ifelse(is.na(WGS_ID) | is.na(WES_ID), "NO", "CONFIRMED")) %>% 
  replace(is.na(.), ".")

write.table(new_validated_map, file="/Users/valkanas/Dropbox (HMS)/Talk_lab/mosaics/ASD_data/master_validation_short_hg38_wes_wgs_map_rel_4pubs.txt",
            sep="\t", row.names = F, quote = F)

### TODO 
#list of samples that need to be added to Terra#
seq_samples <- unlist(new_validated_map$participant_id)
WGS_sites <- new_validated_map %>% filter(participant_id %in% seq_samples)


setwd("/Users/valkanas/Dropbox (HMS)/Talk_lab/mosaics/ASD_data/")

nygc_ped <- read.table("../../sfari/10065_66_SSC.ped", header=F, 
                       col.names = c("FamilyID", "WGS_ID", "Father_WGS_ID", "Mother_WGS_ID", 
                                     "final_ped_sex", "ped_aff"))

nygc_map <- read.csv("../../sfari/nygc_sfari_id_map.csv", header=T) %>%
  mutate(SFARI=SFARI_ID) %>%
  separate(SFARI, c("family_id", "role"), sep="[.]") %>%
  mutate(relation=ifelse(role=="p1", "proband", 
                         ifelse(role=="s1" | role=="s2", "sibling",
                                ifelse(role=="mo", "mother",
                                       ifelse(role=="fa", "father", "error"))))) %>%
  select(-role) %>%
  rename("entity:sample_id"="Repository_Id") %>%
  rename(participant_id=SFARI_ID) %>% 
  mutate(family_id=as.integer(family_id))

ASC_ped <- read.table("../../sfari/ASC_WGS_WES_6448.ped", 
                      header=F, col.names = c("FamilyID", "WGS_ID", "Father_WGS_ID", "Mother_WGS_ID", 
                                              "final_ped_sex", "ped_aff"))
ASC_data <- new_validated_map %>% 
  select("family_id", "participant_id", "WGS_ID", "confirmed_wes_wgs_rel", "WES_ID", "relation") %>%
  distinct() %>%
  rename("entity:sample_id"=WGS_ID) 

ASC_families <- ASC_data %>% select("family_id") %>% unlist()


CCDG_manifest <- read.table("CCDG_Freeze2_External_Crams_manifest.txt", header=F, sep="\t", 
                            col.names = c("size", "unit", "date", "file")) %>%
  mutate(type=ifelse(substr(file,nchar(file)-3,nchar(file))=="crai","cram_index","cram")) %>%
  mutate(new=file) %>%
  separate(new, c("path", "seq_id"), sep="ssc/") %>% 
  separate(seq_id, c("WGS_ID", "files", "ext", "ext2")) %>%
  select("WGS_ID", "file", "type") %>%
  pivot_wider(id_cols=WGS_ID, names_from = type, values_from = file)

CCDG_seq <- read.delim("CCDG_WGS_metadata_terra.tsv", sep = "\t", header=T) %>% 
  rename("sequencing_id"="entity.sequencing_id")

CCDG_seq_full <- full_join(CCDG_seq, CCDG_manifest)

CCDG_subject <- read.delim("../Mutect/Terra/CCDG_subject_table.tsv", header=T, sep="\t") %>%
  select("entity.subject_id", "family_id":"sex") %>%
  rename("WGS_ID"="entity.subject_id")

CCDG_all <- full_join(CCDG_seq_full, CCDG_subject)

samples_table <- CCDG_all %>% filter(family_id %in% ASC_families) %>% 
  rename("entity:sample_id"="WGS_ID") %>%
  left_join(nygc_map) %>% 
  select("entity:sample_id", "cram", "cram_index","family_id", "participant_id", 
         "sequencing_id", "analyte_type", "sequencing_assay":"mother_id", "relation") %>% 
  left_join(ASC_data)

particpants_table <- samples_table %>%
  rename("entity:participant_id"="participant_id") %>%
  select("entity:participant_id", "family_id", "relation", "mother_id", "father_id", "race_ethnicity")

samples_table <- samples_table %>% 
  select(-"mother_id", -"father_id")

write.table(samples_table, "terra_1951_samples.tsv", row.names = F, quote = F, sep="\t")
write.table(particpants_table, "terra_1951_participants.tsv", row.names = F, quote = F, sep="\t")


##remove samples already in Terra "terra_1279_samples.tsv"
exist_samp <- read.delim("terra_1279_samples.tsv", header=T) %>% 
  rename(`entity:sample_id`=entity.sample_id)%>%
  select(-"wes_id") %>% mutate(orig_set=1279)

exist_samp_list <- exist_samp$`entity:sample_id`

full_1951 <- samples_table %>%
  mutate(group=ifelse(`entity:sample_id` %in% exist_samp_list, "1279","new"))

new_samples <- full_1951 %>%
  filter(group == "new") %>%
  select(-"group")

new_participants <- particpants_table %>% 
  filter(!(`entity:participant_id` %in% unlist(exist_samp$participant_id))) 

## I need to move these crams/index files to my own bucket 
write.table(new_samples, "terra_672_new_samples.tsv", row.names = F, quote = F, sep="\t")
write.table(new_participants, "terra_672_new_participants.tsv", row.names = F, quote = F, sep="\t")

files <- c(new_samples$cram, new_samples$cram_index)
write.table(files, "terra_672_file_move.tsv", row.names = F, quote = F, sep="\t")

