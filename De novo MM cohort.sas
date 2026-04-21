
libname aa '/vol/userdata14/sta_room462' ;

/* 영구 library 불러오기 */


/************************************************/
/********************* CCI part ******************/
/************************************************/

proc sql;
create table denovo_cci as
select jid, main_sick, sub_sick, recu_fr_dd

from aa.t200_2023q4_18
where jid in (select jid from aa.denovoMM_v4); quit; *;

data denovo_cci; set denovo_cci;
dig_date = input(RECU_FR_DD, yymmdd10.);
format dig_date yymmdd10.;

drop RECU_FR_DD; run;


proc sql;
create table aa.denovo_cci2 as
select a.*, b.first_mm_date,

case when (      intnx('month',b.first_mm_date,-12,'s')<=a.dig_date<=b.first_mm_date      ) then 1 end as target_diag

from denovo_cci as a left join aa.denovoMM_v4 as b on a.jid=b.jid; quit;



proc sql;
create table aa.denovo_cci3 as
select distinct jid, 

	/*MI*/
	max(      case when (  substr(main_sick,1,3) in ('I21','I22') or substr(main_sick,1,4) in ('I252')  ) and (  target_diag = 1  ) then 1  end      ) as mi_yn1,
	sum(      case when (  substr(sub_sick,1,3) in ('I21','I22') or substr(sub_sick,1,4) in ('I252')  ) and (  target_diag = 1  ) then 1  end      ) as mi_yn0, 

	/*CHF*/
	max(      case when (  substr(main_sick,1,3) in ('I50')  ) and (  target_diag = 1  ) then 1  end      ) as chf_yn1,
    sum(      case when (  substr(sub_sick,1,3) in ('I50')  ) and (  target_diag = 1  ) then 1  end      ) as chf_yn0,

    /*PVD*/
    max(      case when (  substr(main_sick,1,3) in ('I71') or substr(main_sick,1,4) in ('I700','I701','I702','I708','I731','I738','I792','Z958','Z959')  ) and (  target_diag = 1  ) then 1  end      ) as pvd_yn1,
    sum(      case when (  substr(sub_sick,1,3) in ('I71') or substr(sub_sick,1,4) in ('I700','I701','I702','I708','I731','I738','I792','Z958','Z959')  ) and (  target_diag = 1  ) then 1  end      ) as pvd_yn0,

    /*CVD*/
    max(      case when (  substr(main_sick,1,3) in ('G46','I60','I61','I62','I63','I64','I66','I68','I69') or substr(main_sick,1,4) in ('G450','G451','G452','G453','G454','G458','I650','I651','I653','I658','I659','I670','I671','I673','I674','I675','I676','I677','I678','I679')  ) and (  target_diag = 1  ) then 1  end      ) as cvd_yn1,
    sum(      case when (  substr(sub_sick,1,3) in ('G46','I60','I61','I62','I63','I64','I66','I68','I69') or substr(sub_sick,1,4) in ('G450','G451','G452','G453','G454','G458','I650','I651','I653','I658','I659','I670','I671','I673','I674','I675','I676','I677','I678','I679')  ) and (  target_diag = 1  ) then 1  end      ) as cvd_yn0,

    /*Dementia*/
    max(      case when (  substr(main_sick,1,3) in ('F00','F01','F02','F03','G30') or substr(main_sick,1,4) in ('F051','G311')  ) and (  target_diag = 1  ) then 1  end      ) as dem_yn1,
    sum(      case when (  substr(sub_sick,1,3) in ('F00','F01','F02','F03','G30') or substr(sub_sick,1,4) in ('F051','G311')  ) and (  target_diag = 1  ) then 1  end      ) as dem_yn0,

    /*CPD*/
	max(      case when (  substr(main_sick,1,3) in ('J43','J44','J47','J60','J61','J62','J63','J64','J65','J66') or substr(main_sick,1,4) in ('J670','J671','J672','J673','J674','J675','J676','J677','J684','J701','J703')  ) and (  target_diag = 1  ) then 1  end      ) as cpd_yn1,
    sum(      case when (  substr(sub_sick,1,3) in ('J43','J44','J47','J60','J61','J62','J63','J64','J65','J66') or substr(sub_sick,1,4) in ('J670','J671','J672','J673','J674','J675','J676','J677','J684','J701','J703')  ) and (  target_diag = 1  ) then 1  end      ) as cpd_yn0,

    /*Rheumatic disease (connective tissue disease)*/
    max(      case when (  substr(main_sick,1,3) in ('M05','M06','M32','M33','M34') or substr(main_sick,1,4) in ('M315','M351','M353','M360')  ) and (  target_diag = 1  ) then 1  end      ) as rhe_yn1,
    sum(      case when (  substr(sub_sick,1,3) in ('M05','M06','M32','M33','M34') or substr(sub_sick,1,4) in ('M315','M351','M353','M360')  ) and (  target_diag = 1  ) then 1  end      ) as rhe_yn0,

    /*PUD*/
    max(      case when (  substr(main_sick,1,4) in ('K255','K256','K264','K265','K266','K267','K274','K275','K276','K277') or substr(main_sick,1,5) in ('K2541','K2571')  ) and (  target_diag = 1  ) then 1  end      ) as pud_yn1,
    sum(      case when (  substr(sub_sick,1,4) in ('K255','K256','K264','K265','K266','K267','K274','K275','K276','K277') or substr(sub_sick,1,5) in ('K2541','K2571')  ) and (  target_diag = 1  ) then 1  end      ) as pud_yn0,

    /*LD*/
    max(      case when (  substr(main_sick,1,3) in ('B18','K73') or substr(main_sick,1,4) in ('I850','I859','I864','I982','K701','K702','K703','K704','K709','K711','K713','K714','K715','K717','K721','K729','K742','K746','K762','K763','K764','K765','K766','K767','Z944')  ) and (  target_diag = 1  ) then 1  end      ) as ld_yn1,
    sum(      case when (  substr(sub_sick,1,3) in ('B18','K73') or substr(sub_sick,1,4) in ('I850','I859','I864','I982','K701','K702','K703','K704','K709','K711','K713','K714','K715','K717','K721','K729','K742','K746','K762','K763','K764','K765','K766','K767','Z944')  ) and (  target_diag = 1  ) then 1  end      ) as ld_yn0,

    /*DB*/
	max(      case when (  substr(main_sick,1,4) in ('E101','E105','E109','E111','E115','E119','E131','E135','E139','E141','E145','E149')  ) and (  target_diag = 1  ) then 1  end      ) as db_yn1,
    sum(      case when (  substr(sub_sick,1,4) in ('E101','E105','E109','E111','E115','E119','E131','E135','E139','E141','E145','E149')  ) and (  target_diag = 1  ) then 1  end      ) as db_yn0,

    /*Hemiplegia or paraplegia*/
    max(      case when (  substr(main_sick,1,3) in ('G81','G82') or substr(main_sick,1,4) in ('G041','G114','G800','G801','G802','G830','G831','G832','G833','G834','G839')  ) and (  target_diag = 1  ) then 1  end      ) as hp_yn1,
    sum(      case when (  substr(sub_sick,1,3) in ('G81','G82') or substr(sub_sick,1,4) in ('G041','G114','G800','G801','G802','G830','G831','G832','G833','G834','G839')  ) and (  target_diag = 1  ) then 1  end      ) as hp_yn0,

   /*Renal diseases*/
    max(      case when (  substr(main_sick,1,2) in ('N1','N2') or substr(main_sick,1,3) in ('I12','I13','N03','N04','N05','N06','N07','N08') or substr(main_sick,1,4) in ('Z490','Z491','Z492','Z940','Z992')  ) and (  target_diag = 1  ) then 1  end      ) as rd_yn1,
    sum(      case when (  substr(sub_sick,1,2) in ('N1','N2') or substr(sub_sick,1,3) in ('I12','I13','N03','N04','N05','N06','N07','N08') or substr(sub_sick,1,4) in ('Z490','Z491','Z492','Z940','Z992')  ) and (  target_diag = 1  ) then 1  end      ) as rd_yn0,

  /*Any cancer*/
   max(      case when (  substr(main_sick,1,2) in ('C0','C1','C2','C3','C4','C5','C6') or substr(main_sick,1,3) in ('C43','C45','C46','C47','C48','C49','C75','C78','C81','C82','C83','C84','C85','C88','C91','C92','C93','C94','C95')  ) and (  target_diag = 1  ) then 1  end      ) as cancer_yn1,
    sum(      case when (  substr(sub_sick,1,2) in ('C0','C1','C2','C3','C4','C5','C6') or substr(sub_sick,1,3) in ('C43','C45','C46','C47','C48','C49','C75','C78','C81','C82','C83','C84','C85','C88','C91','C92','C93','C94','C95')  ) and (  target_diag = 1  ) then 1  end      ) as cancer_yn0,

   /*AIDS/HIV*/
    max(      case when (  substr(main_sick,1,3) in ('B20','B21','B22','B24')  ) and (  target_diag = 1  ) then 1  end      ) as aids_yn1,
    sum(      case when (  substr(sub_sick,1,3) in ('B20','B21','B22','B24')  ) and (  target_diag = 1  ) then 1  end      ) as aids_yn0

 from aa.denovo_cci2
 group by jid;
 quit;




data denovo_cci_yes; set aa.denovo_cci3;

	if mi_yn1=1 or mi_yn0 >=2 then mi_yes=1;

	if chf_yn1=1 or chf_yn0 >=2 then chf_yes=1;

	if pvd_yn1=1 or pvd_yn0 >=2 then pvd_yes=1;

	if cvd_yn1=1 or cvd_yn0 >=2 then cvd_yes=1;

	if dem_yn1=1 or dem_yn0 >=2 then dem_yes=1;

	if cpd_yn1=1 or cpd_yn0>=2 then cpd_yes=1;

	if rhe_yn1=1 or rhe_yn0>=2 then rhe_yes=1;

	if pud_yn1=1 or pud_yn0>=2 then pud_yes=1;

	if ld_yn1=1 or ld_yn0>=2 then ld_yes=1;

	if db_yn1=1 or db_yn0>=2 then db_yes=1;

	if hp_yn1=1 or hp_yn0>=2 then hp_yes=1;

	if rd_yn1=1 or rd_yn0>=2 then rd_yes=1;

	if cancer_yn1=1 or cancer_yn0>=2 then cancer_yes=1;

	if aids_yn1=1 or aids_yn0>=2 then aids_yes=1;

keep jid mi_yes chf_yes   pvd_yes cvd_yes   dem_yes cpd_yes   rhe_yes pud_yes   ld_yes db_yes  
		hp_yes rd_yes   cancer_yes aids_yes;
run;

proc sql; 
create table denovo_v4 as /*version 4*/
select *

from aa.denovoMM_v4 as a
left join denovo_cci_yes as b on a.jid=b.jid; 
quit; 




/************************************************************************************/
/************ Part 2. 얘는 약제 term을 분석에 필요한 db에 붙이는 과정 ***************/
/************************************************************************************/
/* Part 2에서 만든걸 R로 갖고 가서 분석한다. */


proc sql;
create table MM_medication as
select mid, jid, div_cd, drug_date

from aa.t530_t300_mm_v3
where jid in (select jid from denovo_v4 ); quit; *;


proc sql;
create table MM_medication2 as
select a.*, b.first_mm_date, b.first_mm_age
from MM_medication as a left join denovo_v4 as b on a.jid=b.jid; quit; *;


proc sql;
create table MM_medication3 as
select *
from MM_medication2
where (     first_mm_date^=. and (first_mm_date <= drug_date <= intnx('month', first_mm_date, 2, 's'))      );
quit; *;



/* 약제를 category로 분류 */
proc sql;
create table MM_medication4 as
select *,

case when (  div_cd in ('189901ATB')  ) then 1  end as mel_yn,
case when (  div_cd in ('463301BIJ', '463302BIJ', '463303BIJ')  ) then 1  end as borte_yn,

case when (  div_cd in ('485701ACH', '485702ACH')  ) then 1  end as thali_yn,
case when (  div_cd in ('588201ACH', '588201ATB', '588202ACH', '588202ATB', '588203ACH', '588203ATB',
									'588204ACH', '588204ATB', '588205ACH', '588205ATB', '588206ACH', '588206ATB',
									'588207ACH', '588207ATB')  ) then 1  end as lenal_yn

from MM_medication3;
quit;

proc sql;
create table MM_medication5 as
select *,

max(      case when (mel_yn =1) then 1  end      ) as mel_yn1,
max(      case when (borte_yn = 1) then 1  end      ) as borte_yn1,

max(      case when (thali_yn = 1) then 1  end      ) as thali_yn1,
max(      case when (lenal_yn = 1) then 1  end      ) as lenal_yn1

from MM_medication4
group by jid;
quit;

data MM_medication6; set MM_medication5; drop mel_yn borte_yn thali_yn lenal_yn; run;
proc sort data=MM_medication6 nodupkey out=MM_medication_id; by jid; run;

proc sql;
create table MM_medication_id as
select *,

/* 단독 사용 */
case when (  mel_yn1=1 and borte_yn1=. and thali_yn1=. and lenal_yn1=.  ) then 1  end as mel_only,

case when (  mel_yn1=. and borte_yn1=1 and thali_yn1=. and lenal_yn1=.  ) then 1  end as borte_only,

case when (  mel_yn1=. and borte_yn1=. and thali_yn1=1 and lenal_yn1=.  ) then 1  end as thali_only,

case when (  mel_yn1=. and borte_yn1=. and thali_yn1=. and lenal_yn1=1  ) then 1  end as lenal_only,


/* 2개 combination */
case when (  mel_yn1=1 and borte_yn1=1 and thali_yn1=. and lenal_yn1=.  ) then 1  end as mel_borte,

case when (  mel_yn1=1 and borte_yn1=. and thali_yn1=1 and lenal_yn1=.  ) then 1  end as mel_thali,

case when (  mel_yn1=1 and borte_yn1=. and thali_yn1=. and lenal_yn1=1  ) then 1  end as mel_lenal,

case when (  mel_yn1=. and borte_yn1=1 and thali_yn1=1 and lenal_yn1=.  ) then 1  end as borte_thali,

case when (  mel_yn1=. and borte_yn1=1 and thali_yn1=. and lenal_yn1=1  ) then 1  end as borte_lenal,

case when (  mel_yn1=. and borte_yn1=. and thali_yn1=1 and lenal_yn1=1  ) then 1  end as thali_lenal,


/* 3개 combination */
case when (  mel_yn1=1 and borte_yn1=1 and thali_yn1=1 and lenal_yn1=.  ) then 1  end as mel_borte_thali,

case when (  mel_yn1=1 and borte_yn1=1 and thali_yn1=. and lenal_yn1=1  ) then 1  end as mel_borte_lenal,

case when (  mel_yn1=. and borte_yn1=1 and thali_yn1=1 and lenal_yn1=1  ) then 1  end as borte_thali_lenal,


/* 4개 combination */
case when (  mel_yn1=1 and borte_yn1=1 and thali_yn1=1 and lenal_yn1=1  ) then 1  end as mel_borte_thali_lenal

from MM_medication_id; quit;


/* 다시 묶자 */
proc sql;
create table MM_medication_id2 as
select *,

case when (mel_only=1) then 1  end as mp,

case when (borte_only=1 or borte_lenal=1) then 1  end as vd,

case when (borte_thali=1 or borte_thali_lenal=1) then 1  end as vtd,

case when (mel_borte=1 or mel_borte_thali=1 or mel_borte_lenal=1) then 1  end as vmp,

case when (mel_thali=1 or mel_lenal=1) then 1  end as other

from MM_medication_id; quit;




/* for other term comparison between cohorts */
proc sql;
create table aa.denovo_symMM_other  as

select a.*, b.other, b.mel_thali, b.mel_lenal

from denovo_v4  as a left join mm_medication_id2 as b on a.jid=b.jid; quit;


data aa.denovo_symMM_other; set aa.denovo_symMM_other;

if death_yn=. then death_yn=0; 
if mm_outcome=. then mm_outcome=0; 

/* cci */
if mi_yes=. then mi_yes=0; 
if chf_yes=. then chf_yes=0; 

if pvd_yes=. then pvd_yes=0; 
if cvd_yes=. then cvd_yes=0; 

if dem_yes=. then dem_yes=0; 
if cpd_yes=. then cpd_yes=0; 

if ld_yes=. then ld_yes=0; 
if db_yes=. then db_yes=0; 

if rhe_yes=. then rhe_yes=0; 
if pud_yes=. then pud_yes=0; 

if hp_yes=. then hp_yes=0; 
if rd_yes=. then rd_yes=0; 

if cancer_yes=. then cancer_yes=0; 
if aids_yes=. then aids_yes=0; 


/* other 약물 */
if other=. then other=0;
if mel_thali=. then mel_thali=0;
if mel_lenal=. then mel_lenal=0;

drop mm_yn total_days within_6mths only_6mths smm; 
run;




proc sql;
create table aa.denovo_symMM_v4  as
select a.*, b.mp, b.vd, b.thali_only, b.lenal_only, b.vmp, b.vtd, b.other
from denovo_v4  as a left join mm_medication_id2 as b on a.jid=b.jid; quit;


data aa.denovo_symMM_v4; set aa.denovo_symMM_v4;

if death_yn=. then death_yn=0; 
if mm_outcome=. then mm_outcome=0; 

/* cci */
if mi_yes=. then mi_yes=0; 
if chf_yes=. then chf_yes=0; 

if pvd_yes=. then pvd_yes=0; 
if cvd_yes=. then cvd_yes=0; 

if dem_yes=. then dem_yes=0; 
if cpd_yes=. then cpd_yes=0; 

if ld_yes=. then ld_yes=0; 
if db_yes=. then db_yes=0; 

if rhe_yes=. then rhe_yes=0; 
if pud_yes=. then pud_yes=0; 

if hp_yes=. then hp_yes=0; 
if rd_yes=. then rd_yes=0; 

if cancer_yes=. then cancer_yes=0; 
if aids_yes=. then aids_yes=0; 


/* MM 약물 */
if mp=. then mp=0; 
if vd=. then vd=0; 

if thali_only=. then thali_only=0; 
if lenal_only=. then lenal_only=0; 

if vmp=. then vmp=0; 
if vtd=. then vtd=0; 

if other=. then other=0;

drop mm_yn total_days within_6mths only_6mths smm; 
run;


proc freq data=aa.denovo_symMM_v4; table mm_outcome; run;
