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
library(nnet)


#--- Case 1: Mgus to MM ---#
mgus_to_mm <- read_sas("mgus_to_symmm_v4_lympex.sas7bdat")
nrow(mgus_to_mm)

mgus_to_mm$event<-as.numeric(mgus_to_mm$death_yn)

table(mgus_to_mm$mm_outcome)

mgus_to_mm_sub <- mgus_to_mm[mgus_to_mm$mm_outcome==1,] 
nrow(mgus_to_mm_sub)

# 필요한 열만 select
mgus_to_mm_sub2 = mgus_to_mm_sub %>% dplyr::select(event, death_year, SEX_TP_CD, first_mm_age, c(ends_with('_yes')), mp, vd, thali_only, lenal_only, vmp, vtd, other, death_date, first_mm_date)


#--- Case 2: sMM to MM ---#
smm_to_mm <- read_sas("smm_to_symmm_v4.sas7bdat") 
nrow(smm_to_mm)

smm_to_mm$event<-as.numeric(smm_to_mm$death_yn)
table(smm_to_mm$event)

# CRAB 1yr #
smm_to_mm_sub_1yr = smm_to_mm[(smm_to_mm$hyper_1yr_yes==1 | smm_to_mm$renal_1yr_yes==1 | smm_to_mm$ane_1yr_yes==1 | smm_to_mm$bone_1yr_yes==1),]
nrow(smm_to_mm_sub_1yr)

tmp = smm_to_mm[!(smm_to_mm$JID %in% smm_to_mm_sub_1yr$JID),]
nrow(tmp)

smm_to_mm_sub <- tmp[tmp$mm_outcome==1,] 
nrow(smm_to_mm_sub)


smm_to_mm_sub = smm_to_mm_sub[!(smm_to_mm_sub$other==1),]
nrow(smm_to_mm_sub)

smm_to_mm_sub2 = smm_to_mm_sub %>% 
  dplyr::select(event, death_year, SEX_TP_CD, first_mm_age, c(ends_with("_yes")),mp, vd, thali_only, lenal_only, vmp, vtd, other, death_date, first_mm_date) %>% 
  dplyr::select(-c(  ends_with("_1yr_yes")  ))
nrow(smm_to_mm_sub2)


smm_to_mm_sub_1yr <- smm_to_mm_sub_1yr %>% select(-c("hyper_1yr_yes","renal_1yr_yes","ane_1yr_yes","bone_1yr_yes"))







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

smm_to_mm_sub_1yr = smm_to_mm_sub_1yr %>% 
  dplyr::select(-c(  ends_with("_1yr_yes")  ))

smm_to_mm_sub2 = tmp %>% 
  dplyr::select(event, death_year, SEX_TP_CD, first_mm_age, c(ends_with("_yes")),mp, vd, thali_only, lenal_only, vmp, vtd, other) %>% 
  dplyr::select(-c(  ends_with("_1yr_yes")  ))


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


# select some columns #
denovo_to_mm_sub2 = denovo_to_mm_sub %>% dplyr::select(event, death_year, SEX_TP_CD, first_mm_age, c(ends_with("_yes")),mp, vd, thali_only, lenal_only, vmp, vtd, other, death_date, first_mm_date)



# Case 4-1: Concatenate all groups ------
to_MM <- mgus_to_mm_sub2 %>%
  mutate(group="1:Mgus_to_MM") %>% 
  bind_rows(smm_to_mm_sub2 %>% mutate(group="2:sMM_to_MM")) %>% 
  bind_rows(denovo_to_mm_sub2 %>% mutate(group="3:denovoMM"))


# baseline characteristics #
to_MM$ageg4 <- ifelse(to_MM$first_mm_age<60,"< 60",
                      ifelse(to_MM$first_mm_age<70,"60 - 69",
                             ifelse(to_MM$first_mm_age<80,"70 - 79",">= 80")))

to_MM$ageg4 <- factor(to_MM$ageg4, levels=c("< 60","60 - 69","70 - 79",">= 80"))
to_MM$group <- factor(to_MM$group, levels=c('1:Mgus_to_MM','2:sMM_to_MM','3:denovoMM'), labels=c(1:3))


mytable(group ~ ., data=to_MM[,-c(1:2)], method=3, catMethod=0, show.all=T)
mytable(group ~ ., data=to_MM[,-c(1:2)], method=3, catMethod=0)



# CRAB plus for comparison between three cohorts------
to_MM_CRAB_MM <- read_sas("to_mm_crab_mm.sas7bdat") # Ver1 is first_mm_date + 3,6mths

to_MM_CRAB_MM <- to_MM_CRAB_MM %>% 
  mutate(
    combine_3mths = case_when(hyper_3mths_yes==1 | renal_3mths_yes==1 | ane_3mths_yes==1 | bone_3mths_yes==1 ~ 1, TRUE ~ 0),
    combine_6mths = case_when(hyper_6mths_yes==1 | renal_6mths_yes==1 | ane_6mths_yes==1 | bone_6mths_yes==1 ~ 1, TRUE ~ 0)
  )


mytable(group ~ ., data=to_MM_CRAB_MM[,-c(1:2)], method=3, catMethod=0)



### Score 계산 ------
# Case 1: Mgus to MM ------
cci_score_mgus_to_mm <- mgus_to_mm_sub2 %>%
  mutate(score =
           if_else(mi_yes == 1, 1, 0) +
           if_else(chf_yes == 1, 1, 0) +
           if_else(pvd_yes == 1, 1, 0) +
           if_else(cvd_yes == 1, 1, 0) +
           if_else(dem_yes == 1, 1, 0) +
           if_else(cpd_yes == 1, 1, 0) +
           if_else(rhe_yes == 1, 1, 0) + # rheumatic disease (connective tissue disease)
           if_else(pud_yes == 1, 1, 0) +
           if_else(ld_yes == 1, 1, 0) + # hepatic disease
           if_else(db_yes == 1, 1, 0) +
           if_else(hp_yes == 1, 2, 0) + # hemiplegia or paraplegia
           if_else(rd_yes == 1, 2, 0) + # renal disease
           if_else(cancer_yes == 1, 2, 0) +
           if_else(aids_yes == 1, 6, 0))

cci_score_mgus_to_mm %>% 
  group_by(score) %>% 
  summarise(count = n()) 
print(nrow(cci_score_mgus_to_mm))

# 기초통계량
mean(cci_score_mgus_to_mm$score, na.rm=T);
median(cci_score_mgus_to_mm$score, na.rm=T);
sd(cci_score_mgus_to_mm$score, na.rm=T);
max(cci_score_mgus_to_mm$score, na.rm=T);
min(cci_score_mgus_to_mm$score, na.rm=T)

# Case 2: sMM to MM ------
cci_score_smm_to_mm <- smm_to_mm_sub2 %>%
  mutate(score =
           if_else(mi_yes == 1, 1, 0) +
           if_else(chf_yes == 1, 1, 0) +
           if_else(pvd_yes == 1, 1, 0) +
           if_else(cvd_yes == 1, 1, 0) +
           if_else(dem_yes == 1, 1, 0) +
           if_else(cpd_yes == 1, 1, 0) +
           if_else(rhe_yes == 1, 1, 0) + # rheumatic disease (connective tissue disease)
           if_else(pud_yes == 1, 1, 0) +
           if_else(ld_yes == 1, 1, 0) + # hepatic disease
           if_else(db_yes == 1, 1, 0) +
           if_else(hp_yes == 1, 2, 0) + # hemiplegia or paraplegia
           if_else(rd_yes == 1, 2, 0) + # renal disease
           if_else(cancer_yes == 1, 2, 0) +
           if_else(aids_yes == 1, 6, 0))

cci_score_smm_to_mm %>% 
  group_by(score) %>% 
  summarise(count = n()) 
print(nrow(cci_score_smm_to_mm))

# 기초통계량
mean(cci_score_smm_to_mm$score, na.rm=T);
median(cci_score_smm_to_mm$score, na.rm=T);
sd(cci_score_smm_to_mm$score, na.rm=T);
max(cci_score_smm_to_mm$score, na.rm=T);
min(cci_score_smm_to_mm$score, na.rm=T)


# Case 3: denovo MM------
cci_score_denovo_to_mm <- denovo_to_mm_sub2 %>%
  mutate(score =
           if_else(mi_yes == 1, 1, 0) +
           if_else(chf_yes == 1, 1, 0) +
           if_else(pvd_yes == 1, 1, 0) +
           if_else(cvd_yes == 1, 1, 0) +
           if_else(dem_yes == 1, 1, 0) +
           if_else(cpd_yes == 1, 1, 0) +
           if_else(rhe_yes == 1, 1, 0) + # rheumatic disease (connective tissue disease)
           if_else(pud_yes == 1, 1, 0) +
           if_else(ld_yes == 1, 1, 0) + # hepatic disease
           if_else(db_yes == 1, 1, 0) +
           if_else(hp_yes == 1, 2, 0) + # hemiplegia or paraplegia
           if_else(rd_yes == 1, 2, 0) + # renal disease
           if_else(cancer_yes == 1, 2, 0) +
           if_else(aids_yes == 1, 6, 0))

cci_score_denovo_to_mm %>% 
  group_by(score) %>% 
  summarise(count = n()) 
print(nrow(cci_score_denovo_to_mm))

# 기초통계량
mean(cci_score_denovo_to_mm$score, na.rm=T);
median(cci_score_denovo_to_mm$score, na.rm=T);
sd(cci_score_denovo_to_mm$score, na.rm=T);
max(cci_score_denovo_to_mm$score, na.rm=T);
min(cci_score_denovo_to_mm$score, na.rm=T)


# Case 4: when to_MM ------
cci_score_toMM <- to_MM %>%
  mutate(score =
           if_else(mi_yes == 1, 1, 0) +
           if_else(chf_yes == 1, 1, 0) +
           if_else(pvd_yes == 1, 1, 0) +
           if_else(cvd_yes == 1, 1, 0) +
           if_else(dem_yes == 1, 1, 0) +
           if_else(cpd_yes == 1, 1, 0) +
           if_else(rhe_yes == 1, 1, 0) + # rheumatic disease (connective tissue disease)
           if_else(pud_yes == 1, 1, 0) +
           if_else(ld_yes == 1, 1, 0) + # hepatic disease
           if_else(db_yes == 1, 1, 0) +
           if_else(hp_yes == 1, 2, 0) + # hemiplegia or paraplegia
           if_else(rd_yes == 1, 2, 0) + # renal disease
           if_else(cancer_yes == 1, 2, 0) +
           if_else(aids_yes == 1, 6, 0))

cci_score_toMM %>% 
  group_by(score) %>% 
  summarise(count = n()) 
print(nrow(cci_score_toMM))

# 기초통계량
mean(cci_score_toMM$score, na.rm=T);
median(cci_score_toMM$score, na.rm=T);
sd(cci_score_toMM$score, na.rm=T);
max(cci_score_toMM$score, na.rm=T);
min(cci_score_toMM$score, na.rm=T)

# before matching ------

# print scoring histogram ------
labels = c("mgus_to_mm","smm_to_mm","denovo_to_mm","toMM")
names = c("MGUS to MM", 'SMM to MM', "De novo MM", "All cohorts")


for (i in 1:4){
  dev.new()
  ggplot(get(paste0('cci_score_', labels[i])), aes(x= score)) +
    
    geom_histogram(aes(y = ..density.. ), binwidth = 1, fill='skyblue', color='#1f2d86') +
    geom_density(color = '#fc4e07', size=1, linetype = 'dashed') +
    geom_vline(aes(xintercept = mean(score, na.rm=TRUE)), color='red', linetype = 'dotted', size=1) +
    
    labs(title = names[i], x='Scores', y='Density') +
    theme_minimal() +
    theme(plot.title = element_text(size=20, face='bold', hjust=0.5),
          axis.title.x = element_text(size=18, face='bold'),
          axis.title.y = element_text(size=18, face='bold'),
          axis.text.x = element_text(size=18),
          axis.text.y = element_text(size=18))
  
  ggsave(paste0("250630_ScoringHist_", labels[i], ".pdf"),height=7,width=10,dpi=300)
  
  dev.off()
}


# before matching ------


# plot using 6mths landmark ------

to_MM_6mths_filtered <- to_MM[to_MM$death_year >= 0.5,]
fit_to_MM_6mths <- survfit(Surv(death_year, event) ~ group, data=to_MM_6mths_filtered)

# reverse kaplan-meier curve
reverse_toMM <- copy(to_MM_6mths_filtered)
reverse_toMM$event = ifelse(reverse_toMM$event == 1, 0, 1)

sfit <- survfit(Surv(death_year, event) ~ group, data=reverse_toMM)

sprintf("%.1f (%.1f, %.1f)", surv_median(sfit)[1,2], surv_median(sfit)[1,3], surv_median(sfit)[1,4])
sprintf("%.1f (%.1f, %.1f)", surv_median(sfit)[2,2], surv_median(sfit)[2,3], surv_median(sfit)[2,4])
sprintf("%.1f (%.1f, %.1f)", surv_median(sfit)[3,2], surv_median(sfit)[3,3], surv_median(sfit)[3,4])


# median
median1 = sprintf("%.1f (%.1f, %.1f)", surv_median(fit_to_MM_6mths)[1,2], surv_median(fit_to_MM_6mths)[1,3], surv_median(fit_to_MM_6mths)[1,4])
median2 = sprintf("%.1f (%.1f, %.1f)", surv_median(fit_to_MM_6mths)[2,2], surv_median(fit_to_MM_6mths)[2,3], surv_median(fit_to_MM_6mths)[2,4])
median3 = sprintf("%.1f (%.1f, %.1f)", surv_median(fit_to_MM_6mths)[3,2], surv_median(fit_to_MM_6mths)[3,3], surv_median(fit_to_MM_6mths)[3,4])


# use cox to compare
to_MM_6mths_filtered$group = relevel(to_MM_6mths_filtered$group, ref=3)
cox_fit <- coxph(Surv(time=death_year, event)~group, data=to_MM_6mths_filtered, robust=TRUE)

sum_cox_fit <- summary(cox_fit)
sum_cox_fit

to_MM_6mths_filtered$group = factor(to_MM_6mths_filtered$group, levels=c(1:3))


### Survival probability------
Surv_Prov = function(fit, data, time_point){
  at_times = c(); surv_at_times = c(); groups = c()
  
  for (i in 1:3){
    time = fit$time[data$group==i]
    
    surv = fit$surv[data$group==i]
    group = paste0(i,'th group') 
    
    at_time <- max(time[time <= time_point], na.rm=TRUE) 
    surv_at_time <- surv[which.max(time == at_time)]
    
    at_times <- c(at_times, at_time)
    surv_at_times <- c(surv_at_times, surv_at_time)
    
    groups <- c(groups, group)
  }
  return(data.frame(group_var =groups, time_var = at_times, surv_var = surv_at_times))
}

surv10 = Surv_Prov(fit=fit_to_MM_6mths, data=to_MM_6mths_filtered, time_point=10)

surv1 = paste0(sprintf("%.1f", surv10[1,3]*100),'%')
surv2 = paste0(sprintf("%.1f", surv10[2,3]*100),'%')
surv3 = paste0(sprintf("%.1f", surv10[3,3]*100),'%')



HR1 = sprintf("%.2f (%.2f, %.2f)", sum_cox_fit$conf.int[1,1], sum_cox_fit$conf.int[1,3], sum_cox_fit$conf.int[1,4])
HR2 = sprintf("%.2f (%.2f, %.2f)", sum_cox_fit$conf.int[2,1], sum_cox_fit$conf.int[2,3], sum_cox_fit$conf.int[2,4])


p_val1 = ifelse(    sum_cox_fit$coefficients[1,6]<0.001, "p <.001", paste0(  "p = ", sprintf("%.3f", sum_cox_fit$coefficients[1,6])  )    )
p_val2 = ifelse(    sum_cox_fit$coefficients[2,6]<0.001, "p <.001", paste0(  "p = ", sprintf("%.3f", sum_cox_fit$coefficients[2,6])  )    )


df <- data.frame(`Median survival\n(years)`=c(median1,median2,median3),
                 `HR (95% CI)`=c(HR1, HR2, "Reference"),
                 `P-value`=c(p_val1, p_val2, ""),
                 row.names=c("MGUS to MM","SMM to MM","De novo MM"), check.names=FALSE)



table_grob <- tableGrob(df, theme=ttheme_default(
  core = list(
    fg_params = list(fontsize=10, fontface="plain"),
    bg_params = list(fill = "transparent", col = "black")),
  
  colhead = list(
    fg_params = list(fontsize=10, fontface="plain"),
    bg_params = list(fill = "transparent", col = "black")),
  
  rowhead = list(
    fg_params = list(fontsize=10, fontface="plain"),
    bg_params = list(fill = "transparent", col = "black"))
  
))
table_grob$widths[1] <- unit(1.7, "inches")

################
### plotting ###
################
dev.new()
pdf('250630_ggsurvplot_CRABex_6mthsland.pdf',height=10,width=10)

font_size = 18

p <- ggsurvplot(fit_to_MM_6mths,
                data=to_MM_6mths_filtered,
                
                surv.median.line = "hv",
                risk.table=TRUE,
                
                tables.col = "strata",
                tables.y.text = FALSE,
                
                conf.int=TRUE,
                xlim=c(0,8.5),
                
                xlab="Time (years)",
                ylab="Survival Probability (%)",
                
                legend="none",
                tables.height= 0.2,
                
                break.time.by = 0.5,
                risk.table.fontsize = 5,
                
                palette = pal_lancet()(3)[c(1,3,2)],
                
                tables.theme = theme_cleantable() +
                  theme(plot.title = element_text(size=font_size))
)
p$plot <- p$plot +
  scale_y_continuous(labels = function(x) x*100) +
  
  theme(axis.title.y = element_text(size = font_size),
        axis.text.y = element_text(size = font_size),
        axis.title.x = element_text(size = font_size),
        axis.text.x = element_text(size = font_size))
p
dev.off()

# only result table
dev.new()
pdf('250630_ggsurvplot_CRABex_6mthsland_table.pdf',height=5,width=5)

vp <- viewport(x=0.65, y=0.5, width=0.5, height=0.5, just=c("right","top"))

pushViewport(vp)
grid.draw(table_grob)
popViewport()
dev.off()


####################################
###### mathcing using scores #######
####################################

scoring_MM <- copy(cci_score_toMM)

# bind columns
scoring_MM <- scoring_MM %>% 
  
  rowwise() %>% 
  mutate(
    Doublet = if_else(mp==1 | vd==1 | thali_only==1 | lenal_only==1, 1, 0),
    Low_intensity_triplet = vmp,
    High_intensity_triplet = vtd
  ) %>% 
  ungroup()

scoring_MM <- rename(scoring_MM, "CCI_score"="score")

### for comparison in Doublet, Low_intensity_triplet,  High_intensity_triplet
mytable(group ~ ., data=scoring_MM[,-c(1:2)], method=3, catMethod=0, show.all=T)
mytable(group ~ ., data=scoring_MM[,-c(1:2)], method=3, catMethod=0)


# 6mths landmark ------
# source("./R_spj/MGUS_MM_function.R")
scoring_MM$group1 = factor(as.numeric(scoring_MM$group) - 1)
scoring_MM_6mths_filtered <- scoring_MM[scoring_MM$death_year >= 0.5,]
my_weights = get_sw(group1 ~ ageg4 + SEX_TP_CD + CCI_score + Doublet + Low_intensity_triplet + High_intensity_triplet, data = scoring_MM_6mths_filtered)


scoring_MM_6mths_filtered$group = relevel(scoring_MM_6mths_filtered$group, ref=3)
fit_scoring_MM_6mths <- coxph(Surv(death_year, event) ~ group, data=scoring_MM_6mths_filtered, weights= my_weights$weight, robust=TRUE)

sum_cox_fit <- summary(fit_scoring_MM_6mths)
sum_cox_fit
scoring_MM_6mths_filtered$group = factor(scoring_MM_6mths_filtered$group, levels=c(1:3))

# survival curve
adj_curv <- survfit(Surv(time=death_year, event)~group, data=scoring_MM_6mths_filtered, weights = my_weights$weight)


### reverse kaplan-meier curve
reverse_scoringMM <- copy(scoring_MM_6mths_filtered)
reverse_scoringMM$event = ifelse(reverse_scoringMM$event == 1, 0, 1)

sfit <- survfit(Surv(death_year, event) ~ group, data=reverse_scoringMM, weights = my_weights$weight)
surv_median(sfit)

sprintf("%.1f (%.1f, %.1f)", surv_median(sfit)[1,2], surv_median(sfit)[1,3], surv_median(sfit)[1,4])
sprintf("%.1f (%.1f, %.1f)", surv_median(sfit)[2,2], surv_median(sfit)[2,3], surv_median(sfit)[2,4])
sprintf("%.1f (%.1f, %.1f)", surv_median(sfit)[3,2], surv_median(sfit)[3,3], surv_median(sfit)[3,4])



# median
median1 = sprintf("%.1f (%.1f, %.1f)", surv_median(adj_curv)[1,2], surv_median(adj_curv)[1,3], surv_median(adj_curv)[1,4])
median2 = sprintf("%.1f (%.1f, %.1f)", surv_median(adj_curv)[2,2], surv_median(adj_curv)[2,3], surv_median(adj_curv)[2,4])
median3 = sprintf("%.1f (%.1f, %.1f)", surv_median(adj_curv)[3,2], surv_median(adj_curv)[3,3], surv_median(adj_curv)[3,4])



### Survival probability------
surv10 = Surv_Prov(fit=adj_curv, data=scoring_MM_6mths_filtered, time_point=10)
surv1 = paste0(sprintf("%.1f", surv10[1,3]*100),'%')
surv2 = paste0(sprintf("%.1f", surv10[2,3]*100),'%')
surv3 = paste0(sprintf("%.1f", surv10[3,3]*100),'%')


HR1 = sprintf("%.2f (%.2f, %.2f)", sum_cox_fit$conf.int[1,1], sum_cox_fit$conf.int[1,3], sum_cox_fit$conf.int[1,4])
HR2 = sprintf("%.2f (%.2f, %.2f)", sum_cox_fit$conf.int[2,1], sum_cox_fit$conf.int[2,3], sum_cox_fit$conf.int[2,4])

p_val1 = ifelse(    sum_cox_fit$coefficients[1,6]<0.001, "p <.001", paste0(  "p = ", sprintf("%.3f", sum_cox_fit$coefficients[1,6]) )    )
p_val2 = ifelse(    sum_cox_fit$coefficients[2,6]<0.001, "p <.001", paste0(  "p = ", sprintf("%.3f", sum_cox_fit$coefficients[2,6]) )    )


df <- data.frame(`Median survival\n(years)`=c(median1,median2,median3),
                 `HR (95% CI)`=c(HR1, HR2, "Reference"),
                 `P-value`=c(p_val1, p_val2, ""),
                 row.names=c("MGUS to MM","SMM to MM","De novo MM"), check.names=FALSE)

table_grob <- tableGrob(df, theme=ttheme_default(
  
  core = list(
    fg_params = list(fontsize=10, fontface="plain"),
    bg_params = list(fill = "transparent", col = "black")),
  
  colhead = list(
    fg_params = list(fontsize=10, fontface="plain"),
    bg_params = list(fill = "transparent", col = "black")),
  
  rowhead = list(
    fg_params = list(fontsize=10, fontface="plain"),
    bg_params = list(fill = "transparent", col = "black"))
  
))

table_grob$widths[1] <- unit(1.7, "inches")


##################
### plotting #####
##################
dev.new()
pdf('250630_Adj_ggsurvplot_CRABex_6mthsland.pdf',height=10,width=13)

font_size = 18

p <- ggsurvplot(adj_curv,
                data=scoring_MM_6mths_filtered,
                surv.median.line = "hv",
                risk.table=FALSE,
                
                conf.int=FALSE,
                xlim=c(0,8.5),
                xlab="Time (years)",
                ylab="Survival Probability (%)",
                
                legend="none",
                break.time.by = 0.5,
                palette = pal_lancet()(3)[c(1,3,2)]
)

p$plot <- p$plot +
  scale_y_continuous(labels = function(x) x*100) +
  
  theme(axis.title.y = element_text(size = font_size),
        axis.text.y = element_text(size = font_size),
        axis.title.x = element_text(size = font_size),
        axis.text.x = element_text(size = font_size))
p
dev.off()




# only result table
dev.new()

pdf('250630_Adj_ggsurvplot_CRABex_6mthsland_table.pdf',height=5,width=5)

vp <- viewport(x=0.65, y=0.5, width=0.5, height=0.5, just=c("right","top"))
pushViewport(vp)
grid.draw(table_grob)
popViewport()

dev.off()






###### balance check ------

exp_form = group ~ ageg4 + SEX_TP_CD + CCI_score + Doublet + Low_intensity_triplet + High_intensity_triplet
exp_var = all.vars(exp_form)[1]

summary(my_weights$weight)
tab_smd_adj = svyCreateTableOne(vars = all.vars(exp_form)[-1], strata = exp_var,
                                data=svydesign(ids = ~1, data=scoring_MM_6mths_filtered, weights=my_weights$weight))

tab_smd_un = svyCreateTableOne(vars = all.vars(exp_form)[-1], strata = exp_var,
                               data=svydesign(ids = ~1, data=scoring_MM_6mths_filtered))
tab_smd_adj1 = ExtractSmd(tab_smd_adj) %>% as.data.frame
tab_smd_un1 = ExtractSmd(tab_smd_un) %>% as.data.frame

tab_smd_adj1$variable = rownames(tab_smd_adj1); rownames(tab_smd_adj1) = NULL
tab_smd_un1$variable = rownames(tab_smd_un1); rownames(tab_smd_un1) = NULL
tab_smd_adj1$type = "Adjusted"
tab_smd_un1$type = "Unadjusted"


library(ggsci)



col_val = NULL
col_lab = NULL
var_lab = c("High-intensity triplet", "Low-intensity triplet", "Doublet", "CCI score", "Sex", "Age group")

if(is.null(col_val)){col_val = pal_lancet()(3)[c(1,3,2)]}
if(is.null(col_lab)){col_lab = seq_len(3)-1}

colnames(tab_smd_adj1)[2:4] <- colnames(tab_smd_un1)[2:4] <-
  names(col_val) <- names(col_lab) <- c("SMD12", "SMD13", "SMD23")

tab_smd_res = rbind.data.frame(tab_smd_adj1[,-1], tab_smd_un1[,-1])
tab_smd_res$variable = factor(tab_smd_res$variable, levels = rev(unique(tab_smd_res$variable)),
                              labels = var_lab)

dev.new()
pdf("250630_smdplot.pdf",height=7,width=12)
tab_smd_res %>%
  gather(key = "key", value = "value", -variable, -type) %>%
  ggplot() +
  geom_point(aes(x = value, y = variable, shape = type, col = key),size=3) +
  
  scale_shape_manual(values = c("Adjusted" = 19, "Unadjusted" = 4), name = "") +
  scale_color_manual(values = col_val, labels = c("MGUS to MM",'SMM to MM', "De novo MM"), name = "") +
  geom_vline(aes(xintercept = 0.1), linetype = "dashed") +
  
  labs(x = "Standardized mean difference", y = "Covariates") +
  ggtitle("") +
  
  theme_classic() +
  
  theme(axis.text.y = element_text(size=11),
        axis.title.x = element_text(size=14),
        axis.title.y = element_text(size=14))
dev.off()






#######################
### cuminc task #######
#######################
font_size = 18

common_theme <- theme(
  
  axis.title = element_text(size = font_size),
  axis.text = element_text(size = font_size),
  
  axis.line = element_line(size = 0.5),
  panel.background = element_blank(),
  
  plot.margin = margin(5, 5, 5, 5)
) 

# NewlydiagnosedMGUScohort_to_MGUStoMM in MGUS part------ 
mgus_to_mm <- read_sas("mgus_to_symmm_v4_lympex.sas7bdat") 

nrow(mgus_to_mm)
mgus_to_mm$event<-as.numeric(mgus_to_mm$death_yn)
table(mgus_to_mm$event)

table(mgus_to_mm$mm_outcome)

mgus_to_mm$status = ifelse(mgus_to_mm$mm_outcome==1, 1,
                           ifelse(mgus_to_mm$cr_event==1, 2, 0))
mgus_to_mm$status %>% as.factor %>% summary


# idx date is first_d472_date
mgus_to_mm <- mgus_to_mm %>% mutate(
  time_yr = case_when(
    status == 1 ~ (first_mm_date - first_D472_date)/365.25,
    status == 0 ~ (as.Date('2022-11-30') - first_D472_date)/365.25,
    status == 2 ~ (first_cr_date - first_D472_date)/365.25
  )
)

sum(is.na(mgus_to_mm$time_yr))
sum(mgus_to_mm$time_yr<0)

ci.mgus <- cuminc(ftime=mgus_to_mm$time_yr, fstatus=mgus_to_mm$status, cencode=0)

ci_10y <- sprintf("%.1f", timepoints(ci.mgus,times=10)$est[1,1]*100)
ci_half <- timepoints(ci.mgus,times=10)$est[1,1]/2

ci_est <- ci.mgus$`1 1`$est
ci_time <- ci.mgus$`1 1`$time



# median 누적확률보다 같거나 큰 누적확률  의 time value들  중 맨 첫번째 것
ci_half_time <- ci_time[ci_est >= ci_half][1]

# 10yr confidence interval
est = timepoints(ci.mgus,times=10)$est[1,1]
se = sqrt(timepoints(ci.mgus,times=10)$var[1,1])

lb = est^(exp(-1.96*se/(est*log(est))))
ub = est^(exp(1.96*se/(est*log(est))))
round(est*100,1)
round(lb*100,1); round(ub*100,1)


# time-to-median confidence interval
est = timepoints(ci.mgus,times=ci_half_time)$est[1,1]
se = sqrt(timepoints(ci.mgus,times=ci_half_time)$var[1,1])

lb = est^(exp(-1.96*se/(est*log(est))))
ub = est^(exp(1.96*se/(est*log(est))))
round(est*100,1)
round(lb*100,1); round(ub*100,1)


# cumulative incidence plot
default_gray <- theme_gray()$line$colour
mgus_to_mm = as.data.frame(mgus_to_mm)
mgus_to_mm <- mgus_to_mm %>% 
  
  mutate(
    time_yr = ifelse(time_yr == 0, 1e-5, time_yr)
  )

mgus_dat = crprep(Tstop = "time_yr", 
                  status = "status",
                  
                  data=mgus_to_mm, 
                  trans=1, 
                  
                  cens=0, 
                  id="JID") %>% 
  mutate(sw = weight.cens)

fit_mgus = survfit(Surv(Tstart, Tstop, status==1) ~ 1, data= mgus_dat, weights=sw)

# font_size=12

p <- ggsurvplot(fit_mgus,
                data=mgus_dat,
                risk.table=F,
                legend="none",
                
                conf.int=T,
                censor=F,
                xlab="",
                ylab="",
                
                xlim=c(0,10),
                break.x.by=1,
                legend.title="",
                palette = pal_lancet()(3)[c(2)],
                
                conf.int.fill=pal_lancet()(3)[c(2)],
                fun="event",
                title=""
)
 
p$plot =
  p$plot +
  scale_y_continuous(breaks = c(0, 0.05, 0.1, 0.15, 0.2), labels = function(x) x*100, limits=c(0, 0.2)) +
  common_theme +
  labs(x="Time (years)", y = "Cumulative Incidence (%)") +
  
  geom_vline(xintercept=10, linetype="dashed", color=default_gray, size=0.5) +
  geom_vline(xintercept=ci_half_time, linetype="dashed", color=default_gray, size=0.5)

pdf("250708_mgus_ci.pdf", height=5, width=6.5)
print(p)
dev.off()


p <- ggsurvplot(fit_mgus,
                data=mgus_dat)

p$plot = 
  p$plot +
  annotate(      "text", x=10, y=0.13, label=paste0("10 year\ncumulative incidence\n", ci_10y, "%"), size=5      ) +
  annotate(      "text", x=ci_half_time+0.03, y=0.13, label=paste0(  "Time to median\ncumulative incidence (", sprintf("%.1f", ci_half*100), "%)\n",sprintf("%.1f", ci_half_time)," years"  ), size=5        )

pdf("250708_mgus_ci_onlytable.pdf", height=5, width=6.5)
print(p)
dev.off()


##################################################
################ followup analysis ###############
##################################################

# scoring_MM$group1 = factor(as.numeric(scoring_MM$group) - 1) 앞에서 이 코드까지 돌리고 여기로 넘어와야 한다.

scoring_MM[scoring_MM$group==1,]$first_mm_date


# 6mths followup ------
# source("./R_spj/MGUS_MM_function.R")
followup_analysis <- function(year_num, fu_year){
  
  # before
  # scoring_MM_followup <- scoring_MM[scoring_MM$death_year >= year_num,]
  # scoring_MM_followup$event <- ifelse(scoring_MM_followup$death_year >= fu_year, 0, scoring_MM_followup$event)
  # scoring_MM_followup$death_year <- ifelse(scoring_MM_followup$death_year >= fu_year, (as.Date('2022-11-30') - scoring_MM_followup$first_mm_date)/365.25, scoring_MM_followup$death_year)

  scoring_MM_followup <- scoring_MM[scoring_MM$death_year >= year_num,]
  scoring_MM_followup$event <- ifelse(
    scoring_MM_followup$event == 1 & scoring_MM_followup$death_year > fu_year, 0, scoring_MM_followup$event
  )
  scoring_MM_followup$death_year <- pmin(scoring_MM_followup$death_year, fu_year)
  
  my_weights = get_sw(group1 ~ ageg4 + SEX_TP_CD + CCI_score + Doublet + Low_intensity_triplet + High_intensity_triplet, data = scoring_MM_followup)
  scoring_MM_followup$group = relevel(scoring_MM_followup$group, ref=3)
  fit_scoring_MM_followup <- coxph(Surv(death_year, event) ~ group, data=scoring_MM_followup, weights= my_weights$weight, robust=TRUE)
  
  sum_cox_fit <- summary(fit_scoring_MM_followup)
  scoring_MM_followup$group = factor(scoring_MM_followup$group, levels=c(1:3))
  
  # survival curve
  adj_curv <- survfit(Surv(time=death_year, event)~group, data=scoring_MM_followup, weights = my_weights$weight)
  # median
  median1 = sprintf("%.1f (%.1f, %.1f)", surv_median(adj_curv)[1,2], surv_median(adj_curv)[1,3], surv_median(adj_curv)[1,4])
  median2 = sprintf("%.1f (%.1f, %.1f)", surv_median(adj_curv)[2,2], surv_median(adj_curv)[2,3], surv_median(adj_curv)[2,4])
  median3 = sprintf("%.1f (%.1f, %.1f)", surv_median(adj_curv)[3,2], surv_median(adj_curv)[3,3], surv_median(adj_curv)[3,4])
  
  ### Survival probability------
  surv10 = Surv_Prov(fit=adj_curv, data=scoring_MM_followup, time_point=10)
  surv1 = paste0(sprintf("%.1f", surv10[1,3]*100),'%')
  surv2 = paste0(sprintf("%.1f", surv10[2,3]*100),'%')
  surv3 = paste0(sprintf("%.1f", surv10[3,3]*100),'%')
  
  HR1 = sprintf("%.2f (%.2f, %.2f)", sum_cox_fit$conf.int[1,1], sum_cox_fit$conf.int[1,3], sum_cox_fit$conf.int[1,4])
  HR2 = sprintf("%.2f (%.2f, %.2f)", sum_cox_fit$conf.int[2,1], sum_cox_fit$conf.int[2,3], sum_cox_fit$conf.int[2,4])
  
  p_val1 = ifelse(    sum_cox_fit$coefficients[1,6]<0.001, "p <.001", paste0(  "p = ", sprintf("%.3f", sum_cox_fit$coefficients[1,6]) )    )
  p_val2 = ifelse(    sum_cox_fit$coefficients[2,6]<0.001, "p <.001", paste0(  "p = ", sprintf("%.3f", sum_cox_fit$coefficients[2,6]) )    )
  
  df <- data.frame(`Median survival\n(years)`=c(median1,median2,median3),
                   `HR (95% CI)`=c(HR1, HR2, "Reference"),
                   `P-value`=c(p_val1, p_val2, ""),
                   row.names=c("MGUS to MM","SMM to MM","De novo MM"), check.names=FALSE)
  table_grob <- tableGrob(df, theme=ttheme_default(
    core = list(
      fg_params = list(fontsize=10, fontface="plain"),
      bg_params = list(fill = "transparent", col = "black")),
    colhead = list(
      fg_params = list(fontsize=10, fontface="plain"),
      bg_params = list(fill = "transparent", col = "black")),
    rowhead = list(
      fg_params = list(fontsize=10, fontface="plain"),
      bg_params = list(fill = "transparent", col = "black"))
  ))
  
  table_grob$widths[1] <- unit(1.7, "inches")
  
  ##################
  ### plotting #####
  ##################
  
  font_size = 18
  new_breaks <- c(-0.5, 0,      0.5, 1.5, 2.5, 3.5, 4.5, 5.5, 6.5, 7.5,      8)
  new_labels <- c(0, 0.5,      1, 2, 3, 4, 5, 6, 7, 8,      '')
  
  p <- ggsurvplot(adj_curv,
                  data=scoring_MM_followup,
                  surv.median.line = "hv",
                  risk.table=FALSE,
                  conf.int=FALSE,
                  xlim=c(0,fu_year+year_num),
                  xlab="Time (years)",
                  ylab="Survival Probability (%)",
                  legend="none",
                  break.time.by = 1,
                  palette = pal_lancet()(3)[c(1,3,2)]
  )

  p$plot <- p$plot +
    # geom_segment(aes(x=-0.5, xend=0, y=1, yend=1), color=pal_lancet()(3)[c(2)],size=1) +
    # scale_x_continuous(breaks=new_breaks, labels=new_labels) +
    scale_y_continuous(labels = function(x) x*100) +
    theme(axis.title.y = element_text(size = font_size),
          axis.text.y = element_text(size = font_size),
          axis.title.x = element_text(size = font_size),
          axis.text.x = element_text(size = font_size))

  dev.new()
  pdf(paste0('250630_Adj_ggsurvplot_followup',fu_year,'yr.pdf'),height=10,width=13)
  print(p)
  dev.off()
  
  # only result table
  dev.new()
  pdf(paste0('250630_Adj_ggsurvplot_followup',fu_year,'yr_onlytable.pdf'),height=5,width=6.5)
  
  vp <- viewport(x=0.65, y=0.5, width=0.5, height=0.5, just=c("right","top"))
  pushViewport(vp)
  grid.draw(table_grob)
  popViewport()
  dev.off()}

followup_analysis(0.5,3)
followup_analysis(0.5,4)
followup_analysis(0.5,5)
followup_analysis(0.5,6)

