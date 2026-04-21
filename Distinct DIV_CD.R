# install.packages("writexl")
library(readxl)
library(dplyr)
library(writexl)

# 1. 파일 불러오기
df <- read_excel("C:/Users/chaehyun/Dropbox/Work/PIPET/과제/혈액내과/HIRA_MGUS/반입파일/bispho_반입.xlsx")  # 파일명 수정!

# 2. 주성분코드 기준 중복 제거
df_unique <- df %>% distinct(주성분코드, .keep_all = TRUE)

# 3. 새로운 엑셀 파일로 저장
write_xlsx(df_unique, "C:/Users/chaehyun/Dropbox/Work/PIPET/과제/혈액내과/HIRA_MGUS/반입파일/unique_bispho_반입.xlsx")

