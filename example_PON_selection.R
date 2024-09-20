library(dplyr) 
library(tidyr)

options(stringsAsFactors = F)

setwd("/path")

ped <- read.table("/path/to/ped.txt", 
                  sep="\t", header=T, 
                  col.names=c("family_id", "sample_id", "pat_id", "mat_id", "sex", "affected", "role")) %>%
  mutate(role=tolower(role)) %>%
  distinct()


crams <- read.table("ACE2_sample_cram.txt", sep="\t", header=F, 
                    col.names=c("sample_id", "cram")) %>%
  mutate(cram_index=paste(cram, ".crai", sep=""))

seq_ped <- full_join(crams, ped) 

n_fam <- seq_ped$family_id %>% unique() %>% unlist %>% length
n_fam_mem <- count(seq_ped, family_id)

seq_ped <- full_join(seq_ped, n_fam_mem) %>%
  rename(n_family_members=n) 

relationships <- seq_ped %>% 
  mutate(relationship=ifelse(role=="father" | role == "mother", "parent", "not_parent")) 

all_relationships <- relationships %>% 
  select(family_id, relationship) %>% table() %>% data.frame() %>%
  spread(relationship, Freq)

summary_rel <- all_relationships %>% 
  select(-family_id) %>% table()

PON_size <- 50
num_PON <- 2

sibs <- relationships %>% 
  filter(relationship!="parent" & affected == 1)

all_unaff <- seq_ped %>% 
  filter(affected==1) 

pon_poss <- sibs

all_PON <- data.frame(cram=character(),sample_id=character(), family_id=character(), 
                      pat_id=character(), mat_id=character(), sex=as.integer(character()),
                      affected=as.integer(character()), pon_name=character(), stringsAsFactors=FALSE) 
PON_fams <- character()                    

for (i in 1:num_PON) {
  non_PON <- pon_poss %>% filter(!family_id %in% PON_fams)
  PON_batch <- sample_n(filter(non_PON, sex==2), PON_size/2) %>%
    rbind(sample_n(filter(non_PON, sex==1), PON_size/2)) %>%
    mutate(pon_name=paste("PON", as.character(i), sep = "_"))
  all_PON <- rbind(all_PON, PON_batch)
  PON_fams <- all_PON %>% select(family_id) %>% unlist
}

#### PON batching ####
full_file <- relationships

#evenly assign families to PON ensuring they are not related to anyone in PON
PON_list <- all_PON %>% select(pon_name) %>% unique %>% unlist()

#group seq ped by family id
by_fam <- full_file %>% group_by(family_id)

#Identify PON a family ID is in, exclude it, and select a different PON ID
assign_pon <- function(fam_id) {
  #is this family in a PON
  if ( fam_id %in% PON_fams) {
    xpon <- filter(all_PON, fam_id==family_id)$pon_name
    #what are potential PON to assign this family to
    pon_choices <- PON_list[!PON_list == xpon]
  } else
    pon_choices <- PON_list
  #pick pon for family and return it
  pon <- sample(pon_choices, 1)
  return(pon)
}

#Assign unrelated PON to each family ID 
analysis_fams <- by_fam #%>% full_join(all_fam_structure) %>% filter(fam_structure != "other")

pon_assignments <- mutate(analysis_fams, pon_name = assign_pon(family_id)) %>% 
  ungroup() 

pon_assignments$pon_name %>% table()


#### Format data tables for upload into Terra ####
#table and set assignment for all samples in PON only
#PON data table
PON_table <- all_PON %>%
  rename("entity:pon_id"="sample_id") 
write.table(PON_table, file="ACE2_PON_table.tsv", quote=F, sep="\t", row.names=F)

#PON set table
pon_set_membership <- PON_table %>%
  select(pon_name, "entity:pon_id") %>%
  rename("membership:pon_set_id"="pon_name", "pon"="entity:pon_id")
write.table(pon_set_membership, file="ACE2_PON_set_table.tsv", quote=F, sep="\t", row.names=F)

#sample table for all samples to indicate CRAM paths and which PON to use for each sample
sample_table <- pon_assignments %>%
  rename("entity:sample_id"="sample_id") 
write.table(sample_table, file="ACE2_sample_table.tsv", quote=F, sep="\t", row.names=F)


#


