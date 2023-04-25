library(dplyr) 
library(tidyr)
library(stringr)

options(stringsAsFactors = F)
setwd("/Users/valkanas/Dropbox (HMS)/Talk_lab/mosaics/ASD_data/")

RM_summary <- read.delim("RM_test_summary.txt", header=T)

RM_edit  <- RM_summary %>%
  mutate(RM=strsplit(RMCL, ",")) %>%
  mutate(RM2=unique(as.vector(RM)))

RM_edit  <- RM_summary %>% select(RMCL) %>% unlist()

for (i in 1:length(RM_edit)) {
  sample <- str_split(1,)
}

  mutate(RM=ifelse(!str_detect(RMCL, ","), RMCL,  unique((str_split(RMCL, ","))))) 

RM_summary %>% spread(RMCL, Pass_vars) %>% View()
