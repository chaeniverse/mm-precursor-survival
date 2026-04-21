
libname aa '/vol/userdata14/sta_room462';
/**************************/
/**** smm cohort 제작 *****/
/**************************/


/* D472 없는 애들 뽑는다.*/
proc sql;
create table no_d472_smm as
select *
from aa.t200_2023q4_18 
where jid not in (select distinct jid
						from aa.t200_2023q4_18
						where substr(main_sick,1,4) in ('D472'));
quit; *22,831,043;
/* n수 세기 */
proc sort data=no_d472_smm nodupkey out=no_d472_smm_id; by jid; run; *38,416;


/************************************************/
/*************** Exclusion criteria ***************/
/************************************************/

/*** 1-1. C90 있으면 출력 ***/
proc sql;
create table c90_smm as
select *
from no_d472_smm
where substr(main_sick,1,3) in ('C90');
quit; *1,970,453;
/* n수 세기 */
proc sort data=c90_smm nodupkey out=c90_smm_id; by jid; run; *28,634;


/*** 1-2. C90 한번 받은 애들 뽑기 ***/
proc sql;
create table c90_smm_once as
select distinct jid
from c90_smm
group by jid
having count(jid) =1;
quit; *4,070;

/*** 1-3. C90 두번 이상이면 출력 (= C90 한번 받은 애들 빼기)***/
proc sql;
create table c90_smm_twice as
select *
from c90_smm
where jid not in (select jid
				from c90_smm_once);
quit; *1,966,383;
/* n수 세기 */
proc sort data=c90_smm_twice nodupkey out=c90_smm_twice_id; by jid; run; *24,564;


/*** 2-1. c90 첫 진단 시점 정의 ***/
proc sql;
create table wash_smm as
select *, min(recu_fr_dd) as first_c90_date
from c90_smm_twice
group by jid;
quit;

/* first_c90_date을 date format으로 정의 */
data wash_smm; set wash_smm;

tmp = input(first_c90_date, yymmdd10.);
format tmp yymmdd10.;

drop first_c90_date;
rename tmp = first_c90_date;

run;

/* 아래부터 고 */
/*** 2-2. first_c90_date가 2007, 2008인 경우의 n수 출력***/
proc sql;
create table diagnosis0708 as
select distinct jid

from wash_smm
where year(first_c90_date) in (2007, 2008);

quit; *3,656;

/*** 2-3. wash out period (first_c90_date가 2007, 2008이면 삭제)***/
proc sql;
create table wash_smm2 as
select *

from wash_smm

where jid not in (select jid
						from diagnosis0708);

quit; 
/* n수 세기 */
proc sort data=wash_smm2 nodupkey out=wash_smm2_id; by jid; run; *20,908;

/*** 3-1. C90만 있는 애들에서, V193 있는 애들 뽑는다. C90과 V193은 보통 같이 부여받는대요 ***/
proc sql;
create table v193_smm as

select *
from wash_smm2

where substr(prcl_sym_tp_cd,1,4) in ('V193');
quit; 
/* n수 세기 */
proc sort data=v193_smm nodupkey out=v193_smm_id; by jid; run; *18,916;


/*** 4-1. V193 없는 애들까지 뺀 이 시점에서 c90 첫 진단시 나이를 정의한다. ***/
proc sql;
create table age19_smm as

select *, min(pat_age) as first_c90_age
from v193_smm

group by jid;
quit; 

/*** 4-2. first_c90_age가 <19인 수를 센다. ***/
proc sql;
create table under19_smm as
select distinct jid

from age19_smm
where first_c90_age <19;

quit; *11;

/*** 4-3. first_c90_age가 <19이면 제외한다. ***/
proc sql;
create table age19_smm2 as
select *

from age19_smm

where jid not in (select jid
						from under19_smm);

quit; *1,608,927;
/* n수 세기 */
proc sort data=age19_smm2 nodupkey out=aa.age19_smm2_id; by jid; run; *18,905;


/************************************************************************/
proc sql;
create table smm_mm as

select jid, drug_date, div_cd, drug_age
from aa.t530_t300_mm_v3

where jid in (select jid from aa.age19_smm2_id); quit; 

/* 1-1. mm 약물 정의 (mm 약물 있으면 mm_yn=1로 정의) */
data smm_mm2; set smm_mm;
mm_yn = 1; run;


/*** 1-2-2. drug_date가 first_c90_date 이후인 애들만 pick ***/
proc sql;
create table data as

select a.*, b.first_c90_date
from smm_mm2 as a left join aa.age19_smm2_id as b on a.jid=b.jid; quit;


proc sql;
create table after_c90 as
select distinct jid, mm_yn, min(drug_date) as first_mm_date format=yymmdd10., min(drug_age) as first_mm_age

from data
where (drug_date >= first_c90_date)
group by jid; quit;


/* 여기서 다 갖다 붙이기 */
proc sql;
create table smm_cohort as
select a.jid, a.sex_tp_cd, a.first_c90_date, a.first_c90_age,  

b.mm_yn, b.first_mm_date, b.first_mm_age,  
c.last_dig_date,  d.dgrslt_tp_cd_2

from aa.age19_smm2_id as a left join after_c90 as b on a.jid=b.jid

left join aa.last_dig_date as c on a.jid=c.jid

left join aa.dgrslt_tp_cd_2_id as d on a.jid=d.jid; quit; *;


/* 3-4. 최종 사망 정의 */
data smm_cohort2; set smm_cohort;
if last_dig_date < mdy(11,30,2021) or dgrslt_tp_cd_2 = 1 then death_yn=1; run;


/* death_date 정의 */
data smm_cohort2; set smm_cohort2;

if death_yn=1 then death_date = last_dig_date;

format death_date yymmdd8.; run;


/* death_yn 세기 */
proc freq data=smm_cohort2; table death_yn; run; *death_yn=1  n=;


/* death 관련 변수 정의 */
data smm_cohort3; set smm_cohort2;

if death_yn=. then death_day = mdy(11,30,2022) - first_mm_date;
else if death_yn=1 then death_day = death_date - first_mm_date;

death_year = death_day/365.25;
run;


/***************************************************************/
/************************ outcome 정의 ************************/
/***************************************************************/
/* 1-1. 6개월 이내를 세어본다. */
proc sql;
create table total_days as
select *,

case when (     first_c90_date <= first_mm_date <= intnx('month', first_c90_date, 6, 's')      ) then 1 end as total_days
from smm_cohort3

where mm_yn=1; quit;
proc freq data=total_days; table total_days; run; *total_days=1  n=14,438;


/* 1-2. first c90 date 이후 6개월 이내 사망 */
proc sql;
create table within_6mths as
select *,

case when (     first_c90_date <= death_date <= intnx('month', first_c90_date, 6, 's')      ) then 1 end as within_6mths
from smm_cohort3

where death_yn=1;
quit;
proc freq data=within_6mths; table within_6mths; run; *within_6mths=1  n=;


proc sql;
create table smm_cohort4 as
select a.*, b.total_days, c.within_6mths

from smm_cohort3 as a left join total_days as b on a.jid=b.jid
left join within_6mths as c on a.jid=c.jid;

quit;

/* only_6mths 생성 */
data smm_cohort4; set smm_cohort4;
if total_days = . and within_6mths = 1 then only_6mths=1; run; 
proc freq data=smm_cohort4; table only_6mths; run; *only_6mths=1  1,096;


/* 1-5. C90 이후 6개월 이내 처방이면 mm_outcome=1로 정의한다. -> de novo MM으로 본다. */
data smm_cohort5; set smm_cohort4;
if total_days = 1 then mm_outcome=1;
run;
proc freq data= smm_cohort5; table mm_outcome; run; *mm_outcome=1  n=;


/* death within 6mths 빼기 */
data smm_cohort5; set smm_cohort5;
if only_6mths=.; run; *;


/* mm_outcome=.이면(total_days일 이후 약물 복용한 자들을 의미) smm=1로 정의 */
data smm_cohort5; set smm_cohort5;
if mm_outcome=. then smm=1; run;
proc freq data=smm_cohort5; table smm; run; *smm=1  ;


/* smm=1인 data만 select */
data smm; set smm_cohort5;
if smm=1; 
drop mm_outcome; run;

/* smm db에서 mm_yn=1이면 mm_outcome=1로 코딩 -> smm to symMM */
data smm; set smm;
if mm_yn=1 then mm_outcome=1; run;
proc freq data=smm; table mm_outcome; run; *mm_outcome=1  ;


/* aa.smm_cohort5에서 mm_outcome=1만 keep -> de novo with MM*/
data denovoMM; set smm_cohort5;
if mm_outcome=1; run; *;

/* denovoMM와 smm을 merge */
data final_mm_cohort;
set denovoMM smm; run;


/* 영구 library로 저장해두기 */
data aa.smm_v4; set smm; run;
proc freq data=aa.smm_v4; table mm_outcome; run;

data aa.denovoMM_v4; set denovoMM; run;
proc freq data=aa.denovoMM_v4; table mm_outcome; run;

data aa.final_mm_cohort_v4; set final_mm_cohort; run;
proc freq data=aa.final_mm_cohort_v4; table mm_outcome; run;


/*** t530_t300에서 diagnosis, drug, trtment code check ***/
/* 수혈 코드는 t30만 */

/****************************** T530과 T300과 join한다. ******************************/
/* T530 + T200 */
/*proc sql;
create table aa.T530_T200_v2 as
select *
from aa.T530_2023Q4_18 as a
left join aa.T200_2023Q4_18 as b
on a.mid=b.mid; 
quit;

data aa.T530_T200_v2; set aa.T530_T200_v2;
drug_date = mdy(substr(RECU_FR_DD,5,2), substr(RECU_FR_DD,7,2), substr(RECU_FR_DD,1,4)); format drug_date yymmdd8.;
drug_age = pat_age; 
run;

data aa.T530_T200_v2; set aa.T530_T200_v2;
keep mid jid div_cd drug_date drug_age;
run;

/* T300 + T200 */
/*proc sql;
create table aa.T300_T200_v2 as
select *
from aa.T300_2023Q4_18 as a
left join aa.T200_2023Q4_18 as b
on a.mid=b.mid; 
quit;

data aa.T300_T200_v2; set aa.T300_T200_v2;
drug_date = mdy(substr(RECU_FR_DD,5,2), substr(RECU_FR_DD,7,2), substr(RECU_FR_DD,1,4)); format drug_date yymmdd8.;
drug_age = pat_age; 
run;

data aa.T300_T200_v2; set aa.T300_T200_v2;
keep mid jid div_cd drug_date drug_age;
run;


/* T530 + T300 */
/*proc sql;
create table aa.T530_T300_v2 as
select * 
	from aa.T530_T200_v2
		union all
select *
	from aa.T300_T200_v2;
quit; 

/* jid와 drug_date 순으로 정렬 */
/*proc sort data=aa.T530_T300_v2; by jid drug_date; run;

/************************ smm with CRAB ************************/
/*diganosis code*/
/*proc sql;
create table aa.CRAB_smm_diag as
select *
from aa.t200_2023q4_18
where jid in (select distinct jid from aa.smm_v4); quit;

data aa.CRAB_smm_diag; set  aa.CRAB_smm_diag;
dig_date = mdy(substr(recu_fr_dd,5,2), substr(recu_fr_dd,7,2), substr(recu_fr_dd,1,4)); format dig_date yymmdd10.; run;

proc sql;
create table aa.CRAB_smm_diag as
select a.*, b.first_c90_date
from aa.CRAB_smm_diag as a
left join aa.smm_v4 as b on a.jid=b.jid; quit;

/*medication code*/
/*proc sql;
create table aa.CRAB_smm_medi as 
select *
from aa.t530_t300_v2
where jid in (select distinct jid from aa.smm_v4); quit;

proc sql;
create table aa.CRAB_smm_medi as
select a.*, b.first_c90_date
from aa.CRAB_smm_medi as a
left join aa.smm_v4 as b on a.jid=b.jid; quit;

/*procedure code*/
/*proc sql;
create table aa.CRAB_smm_t30 as
select *
from aa.t300_t200_v2
where jid in (select distinct jid from aa.smm_v4); quit;

proc sql;
create table aa.CRAB_smm_t30 as
select a.*, b.first_c90_date
from aa.CRAB_smm_t30 as a
left join aa.smm_v4 as b on a.jid=b.jid; quit;

/************************************************/
/*************** hypercalcemia ******************/
/************************************************/
/* diag part */
proc sql;
create table diag_filter as
select *,

case when (      intnx('month', first_c90_date, -6, 's')<=dig_date<=intnx('month', first_c90_date, 6, 's')      ) then 1 end as for_1yr

from aa.CRAB_smm_diag; quit;

proc sql;
create table diag_filter2 as
select distinct jid,

/*hypercalcemia*/
max(      case when (  substr(main_sick,1,5) in ("E8352")  ) and (  for_1yr = 1  ) then 1 end      ) as hyper_1yr_yn,

/*renal failure*/
max(      case when (  substr(main_sick,1,4) in ("N183", "N184", "N185")  ) and (  for_1yr = 1  ) then 1 end      ) as renal_1yr_yn,

/*anemia*/
max(      case when (  substr(main_sick,1,4) in ("D630")  ) and (  for_1yr = 1  ) then 1 end      ) as ane_1yr_yn,

/*bone lytic lesion*/
max(      case when (  substr(main_sick,1,3) in ("T08") or substr(main_sick,1,4) in ("M484", "M485", "S220", "S221", "S320", "S327", "S720", "S721") or substr(main_sick,1,5) in ("M8088")  ) and (  for_1yr = 1  ) then 1 end      ) as bone_1yr_yn

from diag_filter
group by jid; quit;


/* medi part */
proc sql;
create table medi_filter as
select *,

case when (      intnx('month', first_c90_date, -6, 's')<=drug_date<=intnx('month', first_c90_date, 6, 's')      ) then 1 end as for_1yr

from aa.CRAB_smm_medi; quit;

proc sql;
create table medi_filter2 as
select distinct jid,

/*hypercalcemia*/
max(      case when (  div_cd in ("420731BIJ", "420732BIJ", "480330BIJ", "207930BIJ")  ) and (  for_1yr = 1  ) then 1 end      ) as hyper_1yr_yn,

/*renal failure*/
max(      case when (  div_cd in ("500334BIJ", "500337BIJ", "500340BIJ", "500341BIJ", "500342BIJ", "500343BIJ", "500330BIJ", "500331BIJ", "500333BIJ", "500338BIJ", "500336BIJ", "500339BIJ", "459701AGN", "459701ATD", "459702ACH")  ) and (  for_1yr = 1  ) then 1 end      ) as renal_1yr_yn,

/*anemia*/
max(      case when (  div_cd in ("500334BIJ", "500337BIJ", "500340BIJ", "500341BIJ", "500342BIJ", "500343BIJ", "500330BIJ", "500331BIJ", "500333BIJ", "500338BIJ", "500336BIJ", "500339BIJ")  ) and (  for_1yr = 1  ) then 1 end      ) as ane_1yr_yn,

/*bone lytic lesion*/
max(      case when (  div_cd in ("420731BIJ", "420732BIJ", "480330BIJ", "480330BIJ", "207930BIJ")  ) and (  for_1yr = 1  ) then 1 end      ) as bone_1yr_yn

from medi_filter
group by jid; quit;



/* trtment part */
proc sql;
create table trt_filter as
select *,

case when (      intnx('month', first_c90_date, -6, 's')<=drug_date<=intnx('month', first_c90_date, 6, 's')      ) then 1 end as for_1yr

from aa.CRAB_smm_t30; quit;

proc sql;
create table trt_filter2 as
select distinct jid,

/*anemia*/
max(      case when (  substr(div_cd,1,5) in ("X2021", "X2022", "X2031", "X2032", "X2091", "X2092", "X2111", "X2112", "X2131", "X2132", "X2512", "X2515", "X1001", "X1002", "X6006", "X6001", "X6002")  ) and (  for_1yr = 1  ) then 1 end      ) as ane_1yr_yn

from trt_filter
group by jid; quit;


proc sql;
create table smm_CRAB_filter as
select a.*, 

/* diagnosis*/
b.hyper_1yr_yn as b_hyper_1yr_yn,

b.renal_1yr_yn as b_renal_1yr_yn,

b.ane_1yr_yn as b_ane_1yr_yn,

b.bone_1yr_yn as b_bone_1yr_yn,


/* medication */
c.hyper_1yr_yn as c_hyper_1yr_yn,

c.renal_1yr_yn as c_renal_1yr_yn,

c.ane_1yr_yn as c_ane_1yr_yn,

c.bone_1yr_yn as c_bone_1yr_yn,


/* procedure */
d.ane_1yr_yn as d_ane_1yr_yn

from aa.smm_v4 as a
left join diag_filter2 as b on a.jid=b.jid

left join medi_filter2 as c on a.jid=c.jid
left join trt_filter2 as d on a.jid=d.jid; quit;



data aa.smm_CRAB_filter2; set smm_CRAB_filter;
/* 1year */
if b_hyper_1yr_yn=1 or c_hyper_1yr_yn=1 then hyper_1yr_yes=1;

if b_renal_1yr_yn=1 or c_renal_1yr_yn=1 then renal_1yr_yes=1;

if b_ane_1yr_yn=1 or c_ane_1yr_yn=1 or d_ane_1yr_yn=1 then ane_1yr_yes=1;

if b_bone_1yr_yn=1 or c_bone_1yr_yn=1 then bone_1yr_yes=1;



keep JID SEX_TP_CD     first_c90_date first_c90_age    first_mm_date first_mm_age     last_dig_date dgrslt_tp_cd_2     death_yn death_date     death_day death_year     mm_outcome hyper_1yr_yes renal_1yr_yes     ane_1yr_yes bone_1yr_yes ; run;



/************************************************/
/********************* CCI part ******************/
/************************************************/
proc sql;
create table first_mm_date_exist as
select *
from aa.smm_CRAB_filter2
where first_mm_date^=.; quit;

proc sql;
create table aa.smm_cci as

select jid, main_sick, sub_sick, recu_fr_dd
from aa.t200_2023q4_18

where jid in (select jid from first_mm_date_exist); quit; *;

data aa.smm_cci; set aa.smm_cci;
dig_date = input(RECU_FR_DD, yymmdd10.);
format dig_date yymmdd10.;
drop RECU_FR_DD; run;


proc sql;
create table aa.smm_cci2 as
select a.*, b.first_mm_date,

case when (      intnx('month',b.first_mm_date,-12,'s')<=a.dig_date<=b.first_mm_date      ) then 1 end as target_diag

from aa.smm_cci as a left join first_mm_date_exist as b on a.jid=b.jid; quit;



proc sql;
create table aa.smm_cci3 as
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

 from aa.smm_cci2
 group by jid;
 quit;


data smm_cci_yes; set aa.smm_cci3;

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
create table smm_to_symMM_v4 as /*version 4*/

select *
from aa.smm_CRAB_filter2 as a

left join smm_cci_yes as b on a.jid=b.jid; 
quit; 




/************************************************************************************/
/************ Part 2. 얘는 약제 term을 분석에 필요한 db에 붙이는 과정 ***************/
/************************************************************************************/
/* index date가 first_mm_date이므로, first_mm_date^=. 인 애들에 대해서만 한다. */

proc sql;
create table MM_medication as

select mid, jid, div_cd, drug_date
from aa.t530_t300_mm_v3

where jid in (select jid from first_mm_date_exist ); quit; *;

proc sql;
create table MM_medication2 as
select a.*, b.first_mm_date, b.first_mm_age
from MM_medication as a left join first_mm_date_exist as b on a.jid=b.jid; quit; *;


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

from MM_medication2
where first_mm_date <= drug_date <= intnx('month', first_mm_date, 2, 's');
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
create table aa.smm_to_symMM_other  as

select a.*, b.other, b.mel_thali, b.mel_lenal

from smm_to_symMM_v4  as a left join mm_medication_id2 as b on a.jid=b.jid; quit;


data aa.smm_to_symMM_other; set aa.smm_to_symMM_other;

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

/* CRAB */
if hyper_1yr_yes=. then hyper_1yr_yes=0; 
if renal_1yr_yes=. then renal_1yr_yes=0; 

if ane_1yr_yes=. then ane_1yr_yes=0; 
if bone_1yr_yes=. then bone_1yr_yes=0; 

run;





proc sql;
create table aa.smm_to_symMM_v4  as

select a.*, b.mp, b.vd, b.thali_only, b.lenal_only, b.vmp, b.vtd, b.other

from smm_to_symMM_v4  as a left join mm_medication_id2 as b on a.jid=b.jid; quit;

data aa.smm_to_symMM_v4; set aa.smm_to_symMM_v4;

/* outcome과 death */
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

/* CRAB */
if hyper_1yr_yes=. then hyper_1yr_yes=0; 
if renal_1yr_yes=. then renal_1yr_yes=0; 

if ane_1yr_yes=. then ane_1yr_yes=0; 
if bone_1yr_yes=. then bone_1yr_yes=0; 

run;


proc freq data=aa.smm_to_symMM_v4; table mm_outcome; run;
