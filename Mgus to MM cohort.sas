libname aa '/vol/userdata14/sta_room462' ;

/*options obs=10000;*/
options obs=max;

/* 내용이 좀 바뀌었다. 첨부터 다시 다 돌려야 할 수도 */


/**************************/
/**** mgus cohort 제작 *****/
/**************************/

/*** 1-1. D472 있으면 출력 
주의) 이 db에는 D472만 있게 된다. ***/
proc sql;
create table d472_mgus as
select *
from aa.t200_2023q4_18
where substr(main_sick,1,4) in ('D472');
quit; 
/* n수 세기 */
proc sort data=d472_mgus nodupkey out=d472_mgus_id; by jid; run; *9,946;


/*** 1-2. D472 한번 받은 애들 뽑기 ***/
proc sql;
create table d472_mgus_once as
select distinct jid
from d472_mgus
group by jid
having count(jid) =1;
quit; *1,909;

/*** 1-3. D472 두번 이상이면 출력 (= D472 한번 받은 애들 빼기)***/
proc sql;
create table d472_mgus_twice as
select *
from d472_mgus
where jid not in (select jid
				from d472_mgus_once);
quit; 
/* n수 세기 */
proc sort data=d472_mgus_twice nodupkey out=d472_mgus_twice_id; by jid; run; *8,037;


/*** 2-1. D472 첫 진단 시점 정의 ***/
proc sql;
create table wash_mgus as
select *, min(recu_fr_dd) as first_D472_date
from d472_mgus_twice
group by jid;
quit;

/* date format으로 정의 */
data wash_mgus; set wash_mgus;
tmp = input(first_D472_date, yymmdd10.);
format tmp yymmdd10.;
drop first_D472_date;
rename tmp = first_D472_date;
run;


/*** 2-2. first_D472_date가 2007, 2008인 경우의 n수 출력***/
proc sql;
create table diagnosis0708 as
select distinct jid
from wash_mgus
where year(first_D472_date) in (2007, 2008);
quit; *258;

/*** 2-3. wash out period (first_D472_date가 2007, 2008이면 삭제)***/
proc sql;
create table wash_mgus2 as
select *
from wash_mgus
where jid not in (select jid
						from diagnosis0708);
quit; 
/* n수 세기 */
proc sort data=wash_mgus2 nodupkey out=wash_mgus2_id; by jid; run; *7,779;


/*** 3-1. D472 첫 진단시 나이를 정의한다. ***/
proc sql;
create table age19_mgus as
select *, min(pat_age) as first_d472_age
from wash_mgus2
group by jid;
quit; 

/*** 3-2. first_d472_age가 <19인 수를 센다. ***/
proc sql;
create table under19_mgus as
select distinct jid
from age19_mgus
where first_d472_age <19;
quit; *5;

/*** 3-3. first_d472_age가 <19이면 제외한다. ***/
proc sql;
create table age19_mgus2 as
select *
from age19_mgus
where jid not in (select jid
						from under19_mgus);
quit; *;
/* n수 세기 */
proc sort data=age19_mgus2 nodupkey out=aa.age19_mgus2_id; by jid; run; *7,774;


/* d472만 갖고 할 수 있는 screening 완료.
t20에서 스크리닝된 jid만 뽑는다.*/
proc sql;
create table screening_d472 as
select *
from aa.t200_2023q4_18 
where jid in (select jid
					from aa.age19_mgus2_id);
quit; 
/* n수 세기 */
proc sort data=screening_d472 nodupkey out=screening_d472_id; by jid; run; *7,774;

/* first_d472_age, first_d472_date 붙이기 */
proc sql;
create table screening_d472 as
select a.*, b.first_d472_date, b.first_d472_age
from screening_d472 as a left join aa.age19_mgus2_id as b on a.jid=b.jid; quit;

data aa.screening_d472; set screening_d472;
dig_date = input(RECU_FR_DD, yymmdd10.);
format dig_date yymmdd10.;
drop RECU_FR_DD;
run;

/*** 4-1. 1차적으로 mgus screening된 jid 있는 t20에서 C90 기록들만 뽑는다. ***/
proc sql;
create table mgus_c90 as
select *
from aa.screening_d472
where substr(main_sick,1,3) in ('C90');
quit; 

/*** 4-2. mgus 진단 후 6개월 이내 혹은 mgus 진단 전에 c90 진단 받은 거 다 뽑기 -> 제외 ***/
proc sql;
create table within_6mths as
select distinct jid,
max(case when (  dig_date <= intnx('month', first_d472_date, 6, 's')  ) then 1 end) as within_6mths
from mgus_c90
group by jid;
quit;
proc freq data=within_6mths; table within_6mths; run; *within_6mths=1  n=2,015;

/* 4-4. within_6mths 한 번이라도 있는 jid 제외 */
proc sql;
create table mgus_c90_6mths as
select *
from screening_d472
where jid not in (select jid
						from within_6mths
						where within_6mths=1);
quit; *;
proc sort data=mgus_c90_6mths nodupkey out=mgus_c90_6mths_id; by jid; run; *5,759;


/* 여기서 다 갖다 붙이기 */
proc sql;
create table mgus_cohort as
select a.jid, a.sex_tp_cd, a.first_d472_date, a.first_d472_age,  

b.last_dig_date,  
c.dgrslt_tp_cd_2

from mgus_c90_6mths_id as a
left join aa.last_dig_date as b on a.jid=b.jid
left join aa.dgrslt_tp_cd_2_id as c on a.jid=c.jid; quit; *;


/* 5-3. 최종 사망 정의 */
data mgus_cohort2; set mgus_cohort;
if last_dig_date < mdy(11,30,2021) or dgrslt_tp_cd_2 = 1 then death_yn=1; run;

/* death_date 정의 */
data mgus_cohort2; set mgus_cohort2;
if death_yn=1 then death_date = last_dig_date;
format death_date yymmdd8.; run;


/* mgus 진단 후 6개월 이내 사망 제외 */
proc sql;
create table death_6mths as
select *,
case when (   first_d472_date <= death_date <= intnx('month', first_d472_date, 6, 's')   ) then 1 end as death_6mths
from mgus_cohort2
where death_yn=1;
quit;
proc freq data=death_6mths; table death_6mths; run; *259;

/*** part 1 - v4 ***/
/* 5-4. death_6mths jid 제외 */
/* 여기까지의 코호트를 mgus_surv_v4으로 내보내기 */
proc sql;
create table aa.mgus_surv_v4 as
select *
from mgus_cohort2
where jid not in (select jid
						from death_6mths
						where death_6mths=1);
quit; *5,500;
/* 이따가 screenig db에 다 갖다 붙일거다. 
jid, sex_tp_cd, first_d472_date, first_d472_age, death_yn last_dig_date death_date */


/******************************************************/
/* 이제 Newly diagnosed MGUS cohort 뒷단 작업 시작 */
/******************************************************/
proc sql;
create table mgus_mm_diagnosis as
select *
from aa.t200_2023q4_18 
where jid in (select jid
					from aa.mgus_surv_v4);
quit; 


/*** 1-1. C90 있는 애들만 출력 ***/
proc sql;
create table mgus_mm_diagnosis2 as
select *
from mgus_mm_diagnosis
where substr(main_sick,1,3) in ('C90');
quit; 

/*** 1-2. C90 두번 받은애들 세기 ***/
/* 고유키 */
proc sql;
create table c90_mgus_cnt as
select distinct jid
from mgus_mm_diagnosis2
group by jid
having count(jid) >=2;
quit; *;


/*** 1-3. C90 두번 이상이면 출력 ***/
proc sql;
create table c90_mgus_twice as
select *
from mgus_mm_diagnosis2
where jid in (select jid
				from c90_mgus_cnt);
quit; 

data c90_mgus_twice; set c90_mgus_twice;
sMM_yn=1; run; *sMM_yn=1이 c90 twice를 의미;

/* n수 세기 */
proc sort data=c90_mgus_twice nodupkey out=c90_mgus_twice_id; by jid; run; *;

/*** 2-1. c90 첫 진단 시점 정의. first_d472_date 이후 ***/
proc sql;
create table c90_mgus_twice2 as
select a.*, b.first_d472_date
from c90_mgus_twice as a left join aa.mgus_surv_v4 as b on a.jid=b.jid; quit;


/* dig_date도 다시 정의 */
data c90_mgus_twice2; set c90_mgus_twice2;
dig_date = input(RECU_FR_DD, yymmdd10.);
format dig_date yymmdd10.;
drop RECU_FR_DD;
run;

/* mgus 진단 후 c90 첫 진단일 정의 */
proc sql;
create table first_c90 as
select *, min(dig_date) as first_c90_date format=yymmdd10., min(pat_age) as first_c90_age
from c90_mgus_twice2
where (dig_date >= first_d472_date)
group by jid;
quit;

/* n수 세기 */
proc sort data=first_c90 nodupkey out=aa.first_c90_id; by jid; run; 
/* 코호트에 붙일 것: sMM_yn first_c90_date first_c90_age */

/*** V193 있는 애들 뽑는다. ***/
proc sql;
create table v193_mgus as
select *, 1 as V193_yn
from first_c90
where substr(prcl_sym_tp_cd,1,4) in ('V193');
quit; 

proc sort data=v193_mgus nodupkey out=aa.v193_mgus_id; by jid; run; *;
/* 코호트에 붙일 것: V193_yn */


proc sql;
create table mgus_mm as
select jid, drug_date, div_cd, drug_age
from aa.t530_t300_mm_v3
where jid in (select jid from aa.v193_mgus_id); quit; 

data mgus_mm2; set mgus_mm;
mm_yn = 1; run;

proc sql;
create table data as
select a.*, b.first_c90_date
from mgus_mm2 as a left join aa.v193_mgus_id as b on a.jid=b.jid; quit;


proc sql;
create table after_c90 as
select *, min(drug_date) as first_mm_date format=yymmdd10., min(drug_age) as first_mm_age
from data
where (drug_date >= first_c90_date) /* MM 약 먹었고 c90 twice도 충족하는 애들에서 */
group by jid; quit;


proc sort data=after_c90 nodupkey out=aa.after_c90_id; by jid; run; *220;
/* 코호트에 붙일 것: first_mm_date, first_mm_age, mm_yn */


/*--- C90 twice & V193 yes (n=338)에서 mm 약물 처방 없이 6개월 내에 죽은 자들을 구한다. ---*/
proc sql;
create table death_within_6mths_chk as
select a.*, b.death_yn, b.death_date, c.first_mm_date, c.first_mm_age, c.mm_yn
from aa.v193_mgus_id as a /**/
left join aa.mgus_surv_v4 as b on a.jid=b.jid
left join aa.after_c90_id as c on a.jid=c.jid; quit; *;

/* C90 진단 후 6개월 내 죽은 이들을 본다. */
proc sql;
create table within_6mths as
select *,
case when (first_c90_date <= death_date <= intnx('month', first_c90_date, 6, 's')) then 1 end as within_6mths
from death_within_6mths_chk
where (death_yn=1);
quit;

proc freq data=within_6mths; table within_6mths; run; *within_6mths=1  n=38;

proc sql;
create table death_within_6mths_chk2 as
select a.*, b.within_6mths
from death_within_6mths_chk as a left join within_6mths as b on a.jid=b.jid;
quit;

/*--- Outcome 정의 ---*/
/* C90 이후 mm 처방이면 mm_outcome=1로 정의한다. */
proc sql;
create table mgus_to_mm_cohort as
select *,
case when (first_mm_date>=first_c90_date) then 1 end as mm_outcome
from death_within_6mths_chk2
where (mm_yn=1); quit; *;

proc freq data=mgus_to_mm_cohort;; table mm_outcome; run; *220;


proc sql;
create table mgus_to_mm_cohort2 as
select a.*, b.mm_outcome
from death_within_6mths_chk2 as a left join mgus_to_mm_cohort as b on a.jid=b.jid;
quit; *;

/* only_6mths 생성 */
data mgus_to_mm_cohort3; set mgus_to_mm_cohort2;
if mm_outcome = . and within_6mths = 1 then only_6mths=1; run; 

proc freq data=mgus_to_mm_cohort3; table only_6mths; run; *only_6mths=1  9;


/* only_6mths 빼기 */
data mgus_to_mm_cohort3; set mgus_to_mm_cohort3;
if only_6mths=.;
only_6mths_ex=1;run; *329;
/* 코호트에 붙일 것: mm_outcome only_6mths_ex */



/* 여기서 다 갖다 붙이기 */
proc sql;
create table aa.final_mgus_cohort as
select a.JID, a.SEX_TP_CD, a.first_d472_date, a.first_d472_age, a.last_dig_date, a.death_yn, a.death_date, /* Newly diagnosed MGUS cohort */
b.first_c90_date, b.first_c90_age, b.sMM_yn, /* C90 twice */
c.V193_yn, /* C90 twice & V193 yes */
d.first_mm_date, d.first_mm_age, d.mm_yn, /* MM prescription */
e.mm_outcome, e.only_6mths_ex /* Outcome definition and only 6mths out */
from aa.mgus_surv_v4 as a 
left join aa.first_c90_id as b on (a.JID=b.JID)
left join aa.v193_mgus_id as c on (a.JID=c.JID)
left join aa.after_c90_id as d on (a.JID=d.JID)
left join mgus_to_mm_cohort3 as e on (a.JID=e.JID); quit; *;




/* death 관련 변수 정의 */
data aa.final_mgus_cohort; set aa.final_mgus_cohort;
if death_yn=. then death_day = mdy(11,30,2022) - first_mm_date;
else if death_yn=1 then death_day = death_date - first_mm_date;
death_year = death_day/365.25;
run;


/*--- CCI ---*/
/* index date가 first_mm_date이므로, first_mm_date^=. 인 애들에 대해서만 한다. */
proc sql;
create table first_mm_date_exist as
select *
from aa.final_mgus_cohort 
where first_mm_date^=.; quit;

proc sql;
create table aa.mgus_cci as
select JID, MAIN_SICK, SUB_SICK, RECU_FR_DD
from aa.t200_2023q4_18
where JID in (select JID from first_mm_date_exist); quit;

data aa.mgus_cci; set aa.mgus_cci; 
dig_date = input(RECU_FR_DD, yymmdd10.);
format dig_date yymmdd10.;
drop RECU_FR_DD;
run;


proc sql;
create table aa.mgus_cci2 as
select a.*, b.first_mm_date,
case when (intnx('month',b.first_mm_date,-12,'s')<=a.dig_date<=b.first_mm_date) then 1 end as target_diag
from aa.mgus_cci as a 
left join first_mm_date_exist as b on (a.JID=b.JID); quit;


proc sql;
create table aa.mgus_cci3 as
select distinct JID,
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
 from aa.mgus_cci2
 group by JID;
 quit;




data mgus_cci_yes; set aa.mgus_cci3;
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
keep jid mi_yes     chf_yes pvd_yes     cvd_yes dem_yes     cpd_yes rhe_yes     pud_yes ld_yes     db_yes hp_yes     rd_yes cancer_yes     aids_yes;
run;

proc sql; 
create table mgus_to_symMM_v4 as
select *
from aa.final_mgus_cohort as a
left join mgus_cci_yes as b on a.jid=b.jid; 
quit; 




/*--- 약제 term db에 붙이기 ---*/

/* index date가 first_mm_date이므로, first_mm_date^=. 인 애들에 대해서만 한다. */

proc sql;
create table MM_medication as
select MID, JID, DIV_CD, drug_date
from aa.t530_t300_mm_v3
where jid in (select jid from first_mm_date_exist ); quit; *;


proc sql;
create table MM_medication2 as
select a.*, b.first_mm_date, b.first_mm_age, b.mm_yn
from MM_medication as a 
left join first_mm_date_exist as b on (a.JID=b.JID); quit; *;


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


/* 고유키 상태 */
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

/* part1 - v4 */
proc sql;
create table aa.mgus_to_symMM_v4_chk  as
/*create table aa.mgus_to_symMM_v4  as*/

select a.*, b.mp, b.vd, b.thali_only, b.lenal_only, b.vmp, b.vtd, b.other

from mgus_to_symMM_v4  as a left join mm_medication_id2 as b on a.jid=b.jid; quit;


data aa.mgus_to_symMM_v4_chk; set aa.mgus_to_symMM_v4_chk;

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

drop within_6mths mm_yn;
run;

