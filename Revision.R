setwd("/vol/userdata14/sta_room462/")
options(scipen = 999)

library(data.table)
library(magrittr)
library(parallel)
library(survival)
library(cmprsk)
library(gridExtra)
library(tableone)
library(moonBook)
library(ggpubr)
library(survey)
library(scales) 
library(knitr)
library(lubridate)

library(grid)
library(mstate)
library(tidyr)
library(sas7bdat)
library(haven)
library(officer)
library(MatchIt)
library(cobalt)
library(VGAM)

library(dplyr)
library(ggplot2)
library(dplyr)
library(WeightIt)
library(ebal)
library(survminer)
library(ggsci)

#--- when index date is first_mm_date ---#
#--- Case 1: Mgus to MM ---#
mgus_to_mm <- read_sas("mgus_to_symmm_v4_lympex.sas7bdat")
nrow(mgus_to_mm)

mgus_to_mm$event<-as.numeric(mgus_to_mm$death_yn)

table(mgus_to_mm$mm_outcome)

mgus_to_mm_sub <- mgus_to_mm[mgus_to_mm$mm_outcome==1,] 
nrow(mgus_to_mm_sub)


#--- Case 2: sMM to MM ---#
smm_to_mm <- read_sas("smm_to_symmm_v4.sas7bdat") 
nrow(smm_to_mm)
smm_to_mm$event<-as.numeric(smm_to_mm$death_yn)

# MM choose
smm_to_mm_sub <- smm_to_mm[smm_to_mm$mm_outcome==1,] 
nrow(smm_to_mm_sub)
# other medication exclude
smm_to_mm_sub = smm_to_mm_sub[smm_to_mm_sub$other==0,]
nrow(smm_to_mm_sub)

# CRAB 1yr #
smm_to_mm_sub_1yr = smm_to_mm_sub[(smm_to_mm_sub$hyper_1yr_yes==1 | smm_to_mm_sub$renal_1yr_yes==1 | smm_to_mm_sub$ane_1yr_yes==1 | smm_to_mm_sub$bone_1yr_yes==1),]
nrow(smm_to_mm_sub_1yr)

tmp = smm_to_mm_sub[!(smm_to_mm_sub$JID %in% smm_to_mm_sub_1yr$JID),]
nrow(tmp)

#--- Case 3: denovo MM ---#
denovo_to_mm <- read_sas("denovo_symmm_v4.sas7bdat")
nrow(denovo_to_mm) 

denovo_to_mm$event<-as.numeric(denovo_to_mm$death_yn)

denovo_to_mm2 = denovo_to_mm %>% 
  bind_rows(smm_to_mm_sub_1yr)
nrow(denovo_to_mm2)

denovo_to_mm_sub <- denovo_to_mm2[denovo_to_mm2$mm_outcome==1,] 
nrow(denovo_to_mm_sub)

denovo_to_mm_sub = denovo_to_mm_sub[!(denovo_to_mm_sub$other==1),]
nrow(denovo_to_mm_sub)



### Revision part = export for CRAB tasks ###
to_MM <- mgus_to_mm_sub %>%
  mutate(group=1) %>% 
  bind_rows(tmp %>% mutate(group=2)) %>% 
  bind_rows(denovo_to_mm_sub %>% mutate(group=3))

to_MM <- to_MM %>% dplyr::select(JID, first_mm_date, group, mm_outcome)

nrow(to_MM)
table(to_MM$group)

# require(writexl)
to_MM$first_mm_date <- ifelse(is.na(to_MM$first_mm_date), "", format(ymd(to_MM$first_mm_date), "%Y%m%d"))

# to_MM[is.na(to_MM$first_c90_date),]
library(writexl)
write_xlsx(to_MM, '/vol/userdata14/sta_room462/250620_to_MM_for_CRAB.xlsx')


#--- CRAB criteria people ---#
to_MM_CRAB_MM <- read_sas("to_mm_crab_mm.sas7bdat") # Ver1 is first_mm_date + 3,6mths

table(to_MM_CRAB_MM$group)


#--- first_mm_date ---#
mgus_to_MM <- to_MM_CRAB_MM[to_MM_CRAB_MM$group==1,]
smm_to_MM <- to_MM_CRAB_MM[to_MM_CRAB_MM$group==2,]
denovo_MM <- to_MM_CRAB_MM[to_MM_CRAB_MM$group==3,]


mgus_to_MM_6mths <- mgus_to_MM %>% filter(hyper_6mths_yes==1 | renal_6mths_yes==1 | ane_6mths_yes==1 | bone_6mths_yes==1)
mgus_to_MM_3mths <- mgus_to_MM %>% filter(hyper_3mths_yes==1 | renal_3mths_yes==1 | ane_3mths_yes==1 | bone_3mths_yes==1)

smm_to_MM_6mths <- smm_to_MM %>% filter(hyper_6mths_yes==1 | renal_6mths_yes==1 | ane_6mths_yes==1 | bone_6mths_yes==1)
smm_to_MM_3mths <- smm_to_MM %>% filter(hyper_3mths_yes==1 | renal_3mths_yes==1 | ane_3mths_yes==1 | bone_3mths_yes==1)


denovo_MM_6mths <- denovo_MM %>% filter(hyper_6mths_yes==1 | renal_6mths_yes==1 | ane_6mths_yes==1 | bone_6mths_yes==1)
denovo_MM_3mths <- denovo_MM %>% filter(hyper_3mths_yes==1 | renal_3mths_yes==1 | ane_3mths_yes==1 | bone_3mths_yes==1)


nrow(mgus_to_MM_6mths); nrow(smm_to_MM_6mths); nrow(denovo_MM_6mths)
nrow(mgus_to_MM_3mths); nrow(smm_to_MM_3mths); nrow(denovo_MM_3mths)

#--- chisq or fisher test ---#

row1 <- c(nrow(mgus_to_MM_3mths), nrow(smm_to_MM_3mths), nrow(denovo_MM_3mths))
row2 <- c(nrow(mgus_to_MM_6mths), nrow(smm_to_MM_6mths), nrow(denovo_MM_6mths))
group <- c("mgus_to_mm", "smm_to_mm", "denovo_mm")

df <- rbind(t(row1), t(row2))
colnames(df) <- c("A","B","C")

chi1 <- chisq.test(df[1,])

#------------------------------------------------#
# 1) sMM군에서 de novo로 가는 군을 +- 3개월로 바꾸기.
# 2) smolMM군에서 c90으로부터 crab까지의 기간에 대한 히스토그램
#------------------------------------------------#


smm_to_mm <- read_sas("smm_crab_win3mths.sas7bdat") 
nrow(smm_to_mm[smm_to_mm$mm_outcome==1,])

smm_to_mm_sub <- smm_to_mm[smm_to_mm$mm_outcome==1,] 
nrow(smm_to_mm_sub)

# medication (other) exclude
table(smm_to_mm_sub$other)

smm_to_mm_sub = smm_to_mm_sub[smm_to_mm_sub$other==0,]
nrow(smm_to_mm_sub)

#--- c90+-3mths ---#

smm_to_mm_sub_3mths = smm_to_mm_sub[(smm_to_mm_sub$hyper_3mths_yes==1 | smm_to_mm_sub$renal_3mths_yes==1 | smm_to_mm_sub$ane_3mths_yes==1 | smm_to_mm_sub$bone_3mths_yes==1),]
nrow(smm_to_mm_sub_3mths) # 591


smm_to_mm_period <- smm_to_mm_sub_3mths %>% 
  mutate(days_c90_to_CRAB = as.numeric(first_CRAB_date-first_c90_date))


ggplot(smm_to_mm_period, aes(x=days_c90_to_CRAB)) +
  geom_histogram(binwidth=30, fill='skyblue', color='black') +
  labs(
    title = "",
    x = "from c90 to CRAB (days)",
    y = "Number of Patients (n=591)"
  ) +
  theme_minimal()

mean(smm_to_mm_period$days_c90_to_CRAB)
hist(smm_to_mm_period$days_c90_to_CRAB, xlab="from C90 to CRAB (days)", ylab = "Number of Patients", col="skyblue", main="CRAB (N=591); Newly diagnosed smolMM (N=3,371)")

?hist()

period_positive = smm_to_mm_period[smm_to_mm_period$days_c90_to_CRAB>=0,]$days_c90_to_CRAB
hist(period_positive, xlab="from C90 to CRAB (days)", ylab = "Number of Patients", col="skyblue", main="CRAB (N=591); Newly diagnosed smolMM (N=3,371)",breaks=30, ylim=c(0,250))
?hist()



#------------------------------------------------#
# 3) sMM군에서 de novo로 가는 군을 beyond 3개월로 바꾸기.
#------------------------------------------------#


smm_to_mm <- read_sas("smm_crab_after3mths.sas7bdat") 
nrow(smm_to_mm) # 1,500
nrow(smm_to_mm[smm_to_mm$mm_outcome==1,]) # 497

smm_to_mm_sub <- smm_to_mm[smm_to_mm$mm_outcome==1,] 
nrow(smm_to_mm_sub)

# medication (other) exclude
table(smm_to_mm_sub$other)

smm_to_mm_sub = smm_to_mm_sub[smm_to_mm_sub$other==0,]
nrow(smm_to_mm_sub) # 484

#--- c90+-3mths ---#

smm_to_mm_sub_3mths = smm_to_mm_sub[(smm_to_mm_sub$hyper_3mths_yes==1 | smm_to_mm_sub$renal_3mths_yes==1 | smm_to_mm_sub$ane_3mths_yes==1 | smm_to_mm_sub$bone_3mths_yes==1),]
nrow(smm_to_mm_sub_3mths) # 423



smm_to_mm_sub_3mths$first_CRAB_date


smm_to_mm_period <- smm_to_mm_sub_3mths %>% 
  mutate(days_c90_to_CRAB = as.numeric(first_CRAB_date-first_c90_date))
# seq(0,100,10)

# par(mar=c(5,4,4,2)+0.1)
hist(smm_to_mm_period$days_c90_to_CRAB, xlab="from C90 to CRAB (days)", ylab = "Number of Patients", col="skyblue", main="CRAB (N=423); Newly diagnosed smolMM (N=3,371)",ylim=c(0,25), breaks=seq(0,5000,20),xaxt="n",xlim=c(0,5000),xaxs="i")
axis(side=1, at=c(0,90,seq(500,5000,500)), labels=c(0,90,seq(500,5000,500)))
hist((smm_to_mm_period$days_c90_to_CRAB)/365.25, xlab="from C90 to CRAB (year)", ylab = "Number of Patients", col="skyblue", main="CRAB (N=423); Newly diagnosed smolMM (N=3,371)",ylim=c(0,600))

?hist


#------------------------------------------------#
# mm - 6mths, mm - 3mths, each C,R,A,B
#------------------------------------------------# 
mgus_to_mm <- read_sas("mgus_to_symmm_v4.sas7bdat")
mgus_to_mm_sub <- mgus_to_mm[mgus_to_mm$mm_outcome==1,] 
nrow(mgus_to_mm_sub)

smm_to_mm <- read_sas("smm_to_symmm_v4.sas7bdat") 
smm_to_mm_sub <- smm_to_mm[smm_to_mm$mm_outcome==1,] 
nrow(smm_to_mm_sub)

# medication (other) exclude
smm_to_mm_sub = smm_to_mm_sub[smm_to_mm_sub$other==0,]
nrow(smm_to_mm_sub)

smm_to_mm_sub_1yr = smm_to_mm_sub[(smm_to_mm_sub$hyper_1yr_yes==1 | smm_to_mm_sub$renal_1yr_yes==1 | smm_to_mm_sub$ane_1yr_yes==1 | smm_to_mm_sub$bone_1yr_yes==1),]
nrow(smm_to_mm_sub_1yr) # 665

# 1yr #
smm_to_mm_sub = smm_to_mm_sub[!(smm_to_mm_sub$JID %in% smm_to_mm_sub_1yr$JID),]
nrow(smm_to_mm_sub) # 447


denovo_to_mm <- read_sas("denovo_symmm_v4.sas7bdat") 
denovo_to_mm_sub <- denovo_to_mm[denovo_to_mm$mm_outcome==1,] 

denovo_to_mm_sub = denovo_to_mm_sub[denovo_to_mm_sub$other==0,]
nrow(denovo_to_mm_sub)


# select some columns #
denovo_to_mm_sub = denovo_to_mm_sub %>% 
  bind_rows(smm_to_mm_sub_1yr)
nrow(denovo_to_mm_sub)

mgus_to_mm_sub <- mgus_to_mm_sub %>% select(JID, first_mm_date, first_c90_date)
smm_to_mm_sub <- smm_to_mm_sub %>% select(JID, first_mm_date, first_c90_date)
denovo_to_mm_sub <- denovo_to_mm_sub %>% select(JID, first_mm_date, first_c90_date)



# Case 4-1: Concatenate all groups ------
to_MM <- mgus_to_mm_sub %>%
  mutate(group=1) %>% 
  bind_rows(smm_to_mm_sub %>% mutate(group=2)) %>% 
  bind_rows(denovo_to_mm_sub %>% mutate(group=3))


to_MM$first_c90_date <- ifelse(is.na(to_MM$first_c90_date), "", format(ymd(to_MM$first_c90_date), "%Y%m%d"))
to_MM$first_mm_date <- ifelse(is.na(to_MM$first_mm_date), "", format(ymd(to_MM$first_mm_date), "%Y%m%d"))
write_xlsx(to_MM, '/vol/userdata14/sta_room462/250620_to_MM_for_CRAB.xlsx')



to_MM_CRAB_MM <- read_sas("to_mm_crab_mm_v2.sas7bdat") # Ver2 is first_mm_date - 3,6mths
table(to_MM_CRAB_MM$group)

#--- first_mm_date ---#

mytable(group ~ ., data=to_MM_CRAB_MM[,-c(1:2)], method=3, catMethod=0, show.all=F)


mgus_to_MM_6mths <- mgus_to_MM %>% filter(hyper_6mths_yes==1 | renal_6mths_yes==1 | ane_6mths_yes==1 | bone_6mths_yes==1)
mgus_to_MM_3mths <- mgus_to_MM %>% filter(hyper_3mths_yes==1 | renal_3mths_yes==1 | ane_3mths_yes==1 | bone_3mths_yes==1)

smm_to_MM_6mths <- smm_to_MM %>% filter(hyper_6mths_yes==1 | renal_6mths_yes==1 | ane_6mths_yes==1 | bone_6mths_yes==1)
smm_to_MM_3mths <- smm_to_MM %>% filter(hyper_3mths_yes==1 | renal_3mths_yes==1 | ane_3mths_yes==1 | bone_3mths_yes==1)


denovo_MM_6mths <- denovo_MM %>% filter(hyper_6mths_yes==1 | renal_6mths_yes==1 | ane_6mths_yes==1 | bone_6mths_yes==1)
denovo_MM_3mths <- denovo_MM %>% filter(hyper_3mths_yes==1 | renal_3mths_yes==1 | ane_3mths_yes==1 | bone_3mths_yes==1)


nrow(mgus_to_MM_6mths); nrow(smm_to_MM_6mths); nrow(denovo_MM_6mths)
nrow(mgus_to_MM_3mths); nrow(smm_to_MM_3mths); nrow(denovo_MM_3mths)



# [25-07-31] CRAB: BisphoEx and within 3mths------

CRAB_MM <- read_sas("mm_crab_bisphoex.sas7bdat") 
table(CRAB_MM$group)

#--- first_mm_date ---#

mytable(group ~ ., data=CRAB_MM[,-c(1:2)], method=3, catMethod=0, show.all=F)


# CRAB plus for comparison between three cohorts------
CRAB_MM <- CRAB_MM %>% 
  mutate(
    combine_3mths = case_when(hyper_3mths_yes==1 | renal_3mths_yes==1 | ane_3mths_yes==1 | bone_3mths_yes==1 ~ 1, TRUE ~ 0)
  )


mytable(group ~ ., data=CRAB_MM[,-c(1:2)], method=3, catMethod=0)


