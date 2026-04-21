
libname aa '/vol/userdata14/sta_room462';
/* three cohorts에서 CRAB pattern check */

/* double chk */
/*proc sql;
create table chk as
select jid, mid, div_cd, drug_date, count(*) as cnt
from aa.t530_t300_mm_2
group by jid, mid, div_cd, drug_date
having cnt > 1; quit;*/




/* 수혈 코드는 t30만 */

/*** CRAB - t20 part (diagnosis code) ***/
proc sql;
create table aa.crab_t20 as
select *
from aa.t200_2023q4_18
where substr(main_sick,1,5) in ("E8352", "M8088") or 
substr(main_sick,1,4) in ("N183", "N184", "N185", "D630", "M484", "M485", "S220", "S221", "S320", "S327", "S720", "S721") or 
substr(main_sick,1,3) in ("T08"); quit;

/*** CRAB - t30 part (수혈 & treatment code) ***/
proc sql;
create table aa.crab_t30 as
select *
from aa.t300_2023q4_18
where div_cd in ("420731BIJ", "420732BIJ", "480330BIJ", "207930BIJ", 
"500334BIJ", "500337BIJ", "500340BIJ", "500341BIJ", "500342BIJ", 
"500343BIJ", "500330BIJ", "500331BIJ", "500333BIJ", "500338BIJ", 
"500336BIJ", "500339BIJ", "459701AGN", "459701ATD", "459702ACH") or 
substr(div_cd,1,5) in ("X2021", "X2022", "X2031", "X2032", "X2091", "X2092", "X2111", "X2112", "X2131", "X2132", "X2512", "X2515", "X1001", "X1002", "X6006", "X6001", "X6002"); quit;


/*** CRAB - t53 part (treatment code) ***/
proc sql;
create table aa.crab_t53 as
select *
from aa.t530_2023q4_18
where div_cd in ("420731BIJ", "420732BIJ", "480330BIJ", "207930BIJ", 
"500334BIJ", "500337BIJ", "500340BIJ", "500341BIJ", "500342BIJ", 
"500343BIJ", "500330BIJ", "500331BIJ", "500333BIJ", "500338BIJ", 
"500336BIJ", "500339BIJ", "459701AGN", "459701ATD", "459702ACH"); quit;

proc sql;
create table crab_t30_t20 as
select a.JID, a.MID, a.RECU_FR_DD, b.DIV_CD
from aa.T200_2023q4_18 as a 
left join aa.crab_t30 as b on a.MID=b.MID; quit;

proc sql;
create table crab_t30_t20_medi_only as
select *
from crab_t30_t20
where div_cd in ("420731BIJ", "420732BIJ", "480330BIJ", "207930BIJ", 
"500334BIJ", "500337BIJ", "500340BIJ", "500341BIJ", "500342BIJ", 
"500343BIJ", "500330BIJ", "500331BIJ", "500333BIJ", "500338BIJ", 
"500336BIJ", "500339BIJ", "459701AGN", "459701ATD", "459702ACH"); quit;


proc sql;
create table aa.crab_t30_t20_procedure as
select *
from crab_t30_t20
where substr(div_cd,1,5) in ("X2021", "X2022", "X2031", "X2032", "X2091", 
"X2092", "X2111", "X2112", "X2131", "X2132", "X2512", "X2515", "X1001", 
"X1002", "X6006", "X6001", "X6002"); quit;
proc sort data= aa.crab_t30_t20_procedure; by JID RECU_FR_DD; quit;


proc sql;
create table crab_t53_t20 as
select a.JID, a.MID, a.RECU_FR_DD, b.DIV_CD
from aa.T200_2023q4_18 as a 
left join aa.crab_t53 as b on a.MID=b.MID; quit;

proc sql;
create table aa.crab_medication as
select *
    from crab_t53_t20
	    union all
select *
    from crab_t30_t20_medi_only;
quit;

proc sort data=aa.crab_medication; by JID RECU_FR_DD; quit;


proc import datafile='/vol/userdata14/sta_room462/250620_to_MM_for_CRAB.xlsx'
dbms=xlsx
out=to_MM;
run;

/*********************************************************/
/******************************************************/


/*** import cohort ***/

proc sql;
create table three_cohort_combined as
select JID, first_mm_date, group
from to_MM; quit;

data three_cohort_combined2; set three_cohort_combined;
tmp2 = mdy(substr(first_mm_date,5,2), substr(first_mm_date,7,2), substr(first_mm_date,1,4)); format tmp2 yymmdd8.; 
drop  first_mm_date; rename tmp2=first_mm_date; run;
run;

/*********************************************************/
/******************************************************/



/*---diganosis code---*/
proc sql;
create table crab_t20_to_MM as
select *
from aa.crab_t20
where jid in (select  jid from three_cohort_combined2); quit;

data crab_t20_to_MM; set  crab_t20_to_MM;
dig_date = mdy(substr(recu_fr_dd,5,2), substr(recu_fr_dd,7,2), substr(recu_fr_dd,1,4)); format dig_date yymmdd8.; run;

proc sql;
create table crab_t20_to_MM2 as
select a.*, b.first_mm_date
from crab_t20_to_MM as a
left join three_cohort_combined2 as b on a.jid=b.jid; quit;

/*---medication code---*/
proc sql;
create table crab_medication_to_MM as
select *
from aa.crab_medication
where jid in (select  jid from three_cohort_combined2); quit;

data crab_medication_to_MM; set  crab_medication_to_MM;
drug_date = mdy(substr(recu_fr_dd,5,2), substr(recu_fr_dd,7,2), substr(recu_fr_dd,1,4)); format drug_date yymmdd8.; run;

proc sql;
create table crab_medication_to_MM2 as
select a.*, b.first_mm_date
from crab_medication_to_MM as a
left join three_cohort_combined2 as b on a.jid=b.jid; quit;


/*---procedure code---*/
proc sql;
create table crab_procedure_to_MM as
select *
from aa.crab_t30_t20_procedure
where jid in (select  jid from three_cohort_combined2); quit;

data crab_procedure_to_MM; set  crab_procedure_to_MM;
proc_date = mdy(substr(recu_fr_dd,5,2), substr(recu_fr_dd,7,2), substr(recu_fr_dd,1,4)); format proc_date yymmdd8.; run;

proc sql;
create table crab_procedure_to_MM2 as
select a.*, b.first_mm_date
from crab_procedure_to_MM as a
left join three_cohort_combined2 as b on a.jid=b.jid; quit;




/*---first_mm_date ---*/

/* diag part */
proc sql;
create table diag_filter as
select *,
case when (first_mm_date<=dig_date<=intnx('month', first_mm_date, 3, 's')) then 1 end as for_3mths,
case when (first_mm_date<=dig_date<=intnx('month', first_mm_date, 6, 's')) then 1 end as for_6mths
from crab_t20_to_MM2; quit;

proc sql;
create table diag_filter2 as
select DISTINCT JID,
/*hypercalcemia*/
max(case when (substr(main_sick,1,5) in ("E8352")) and (for_6mths = 1) then 1 end) as hyper_6mths_yn,
/*renal failure*/
max(case when (substr(main_sick,1,4) in ("N183", "N184", "N185")) and (for_6mths = 1) then 1 end) as renal_6mths_yn,
/*anemia*/
max(case when (substr(main_sick,1,4) in ("D630")) and (for_6mths = 1) then 1 end) as ane_6mths_yn,
/*bone lytic lesion*/
max(case when (substr(main_sick,1,3) in ("T08") or substr(main_sick,1,4) in ("M484", "M485", "S220", "S221", "S320", "S327", "S720", "S721") or substr(main_sick,1,5) in ("M8088")) and (for_6mths = 1) then 1 end) as bone_6mths_yn,

/*hypercalcemia*/
max(case when (substr(main_sick,1,5) in ("E8352")) and (for_3mths = 1) then 1 end) as hyper_3mths_yn,
/*renal failure*/
max(case when (substr(main_sick,1,4) in ("N183", "N184", "N185")) and (for_3mths = 1) then 1 end) as renal_3mths_yn,
/*anemia*/
max(case when (substr(main_sick,1,4) in ("D630")) and (for_3mths = 1) then 1 end) as ane_3mths_yn,
/*bone lytic lesion*/
max(case when (substr(main_sick,1,3) in ("T08") or substr(main_sick,1,4) in ("M484", "M485", "S220", "S221", "S320", "S327", "S720", "S721") or substr(main_sick,1,5) in ("M8088")) and (for_3mths = 1) then 1 end) as bone_3mths_yn
from diag_filter
group by JID; quit;


/* medi part */
proc sql;
create table medi_filter as
select *,
case when (first_mm_date<=drug_date<=intnx('month', first_mm_date, 3, 's')) then 1 end as for_3mths,
case when (first_mm_date<=drug_date<=intnx('month', first_mm_date, 6, 's')) then 1 end as for_6mths
from crab_medication_to_MM2; quit;

proc sql;
create table medi_filter2 as
select DISTINCT JID,

/*hypercalcemia*/
max(case when (div_cd in ("420731BIJ", "420732BIJ", "480330BIJ", "207930BIJ")) and (for_6mths = 1) then 1 end) as hyper_6mths_yn,
/*renal failure*/
max(case when (div_cd in ("500334BIJ", "500337BIJ", "500340BIJ", "500341BIJ", "500342BIJ", "500343BIJ", "500330BIJ", "500331BIJ", "500333BIJ", "500338BIJ", "500336BIJ", "500339BIJ", "459701AGN", "459701ATD", "459702ACH")) and (for_6mths = 1) then 1 end) as renal_6mths_yn,
/*anemia*/
max(case when (div_cd in ("500334BIJ", "500337BIJ", "500340BIJ", "500341BIJ", "500342BIJ", "500343BIJ", "500330BIJ", "500331BIJ", "500333BIJ", "500338BIJ", "500336BIJ", "500339BIJ")) and (for_6mths = 1) then 1 end) as ane_6mths_yn,
/*bone lytic lesion*/
max(case when (div_cd in ("420731BIJ", "420732BIJ", "480330BIJ", "480330BIJ", "207930BIJ")) and (for_6mths = 1) then 1 end) as bone_6mths_yn,

/*hypercalcemia*/
max(case when (div_cd in ("420731BIJ", "420732BIJ", "480330BIJ", "207930BIJ")) and (for_3mths = 1) then 1 end) as hyper_3mths_yn,
/*renal failure*/
max(case when (div_cd in ("500334BIJ", "500337BIJ", "500340BIJ", "500341BIJ", "500342BIJ", "500343BIJ", "500330BIJ", "500331BIJ", "500333BIJ", "500338BIJ", "500336BIJ", "500339BIJ", "459701AGN", "459701ATD", "459702ACH")) and (for_3mths = 1) then 1 end) as renal_3mths_yn,
/*anemia*/
max(case when (div_cd in ("500334BIJ", "500337BIJ", "500340BIJ", "500341BIJ", "500342BIJ", "500343BIJ", "500330BIJ", "500331BIJ", "500333BIJ", "500338BIJ", "500336BIJ", "500339BIJ")) and (for_3mths = 1) then 1 end) as ane_3mths_yn,
/*bone lytic lesion*/
max(case when (div_cd in ("420731BIJ", "420732BIJ", "480330BIJ", "480330BIJ", "207930BIJ")) and (for_3mths = 1) then 1 end) as bone_3mths_yn

from medi_filter
group by JID; quit;

/* trtment part */
proc sql;
create table proc_filter as
select *,
case when (first_mm_date<=proc_date<=intnx('month', first_mm_date, 3, 's')) then 1 end as for_3mths,
case when (first_mm_date<=proc_date<=intnx('month', first_mm_date, 6, 's')) then 1 end as for_6mths
from crab_procedure_to_MM2; quit;

proc sql;
create table proc_filter2 as
select DISTINCT JID,
/*anemia*/
max(case when (substr(div_cd,1,5) in ("X2021", "X2022", "X2031", "X2032", "X2091", "X2092", "X2111", "X2112", "X2131", "X2132", "X2512", "X2515", "X1001", "X1002", "X6006", "X6001", "X6002")) and (for_6mths = 1) then 1 end) as ane_6mths_yn,

/*anemia*/
max(case when (substr(div_cd,1,5) in ("X2021", "X2022", "X2031", "X2032", "X2091", "X2092", "X2111", "X2112", "X2131", "X2132", "X2512", "X2515", "X1001", "X1002", "X6006", "X6001", "X6002")) and (for_3mths = 1) then 1 end) as ane_3mths_yn

from proc_filter
group by JID; quit;


proc sql;
create table to_MM_CRAB as
select a.*, 

/* diagnosis*/
b.hyper_6mths_yn as b_hyper_6mths_yn,
b.renal_6mths_yn as b_renal_6mths_yn,
b.ane_6mths_yn as b_ane_6mths_yn,
b.bone_6mths_yn as b_bone_6mths_yn,

/* medication */
c.hyper_6mths_yn as c_hyper_6mths_yn,
c.renal_6mths_yn as c_renal_6mths_yn,
c.ane_6mths_yn as c_ane_6mths_yn,
c.bone_6mths_yn as c_bone_6mths_yn,

/* procedure */
d.ane_6mths_yn as d_ane_6mths_yn,


/* diagnosis*/
b.hyper_3mths_yn as b_hyper_3mths_yn,
b.renal_3mths_yn as b_renal_3mths_yn,
b.ane_3mths_yn as b_ane_3mths_yn,
b.bone_3mths_yn as b_bone_3mths_yn,

/* medication */
c.hyper_3mths_yn as c_hyper_3mths_yn,
c.renal_3mths_yn as c_renal_3mths_yn,
c.ane_3mths_yn as c_ane_3mths_yn,
c.bone_3mths_yn as c_bone_3mths_yn,

/* procedure */
d.ane_3mths_yn as d_ane_3mths_yn


from to_MM as a
left join diag_filter2 as b on a.jid=b.jid
left join medi_filter2 as c on a.jid=c.jid
left join proc_filter2 as d on a.jid=d.jid; quit;


data aa.to_MM_CRAB_MM; set to_MM_CRAB;
/*data aa.to_MM_CRAB_MM; set to_MM_CRAB;*/
/* 6mths */
if b_hyper_6mths_yn=1 or c_hyper_6mths_yn=1 then hyper_6mths_yes=1;
if b_renal_6mths_yn=1 or c_renal_6mths_yn=1 then renal_6mths_yes=1;
if b_ane_6mths_yn=1 or c_ane_6mths_yn=1 or d_ane_6mths_yn=1 then ane_6mths_yes=1;
if b_bone_6mths_yn=1 or c_bone_6mths_yn=1 then bone_6mths_yes=1;

/* 3mths */
if b_hyper_3mths_yn=1 or c_hyper_3mths_yn=1 then hyper_3mths_yes=1;
if b_renal_3mths_yn=1 or c_renal_3mths_yn=1 then renal_3mths_yes=1;
if b_ane_3mths_yn=1 or c_ane_3mths_yn=1 or d_ane_3mths_yn=1 then ane_3mths_yes=1;
if b_bone_3mths_yn=1 or c_bone_3mths_yn=1 then bone_3mths_yes=1;

keep JID  
first_mm_date   group
hyper_6mths_yes renal_6mths_yes ane_6mths_yes bone_6mths_yes
hyper_3mths_yes renal_3mths_yes ane_3mths_yes bone_3mths_yes ; run;



data aa.to_MM_CRAB_MM; set aa.to_MM_CRAB_MM;


if hyper_3mths_yes=. then hyper_3mths_yes=0;
if renal_3mths_yes=. then renal_3mths_yes=0;
if ane_3mths_yes=. then ane_3mths_yes=0;
if bone_3mths_yes=. then bone_3mths_yes=0;

if hyper_6mths_yes=. then hyper_6mths_yes=0;
if renal_6mths_yes=. then renal_6mths_yes=0;
if ane_6mths_yes=. then ane_6mths_yes=0;
if bone_6mths_yes=. then bone_6mths_yes=0;
run;



proc sql;
create table smm_chk as
select *
from aa.to_MM_CRAB_MM
where group = 2 and mm_outcome=1; quit;


/*------------------------------------------------*/
/* 아래는 그외 필요할 수도 있는 코드 일부들*/
/*------------------------------------------------*/

/*---diganosis code---*/
proc sql;
create table crab_t20_to_MM as
select *
from aa.crab_t20
where jid in (select  jid from aa.smm_v4); quit;

data crab_t20_to_MM; set  crab_t20_to_MM;
dig_date = mdy(substr(recu_fr_dd,5,2), substr(recu_fr_dd,7,2), substr(recu_fr_dd,1,4)); format dig_date yymmdd8.; run;

proc sql;
create table crab_t20_to_MM2 as
select a.*, b.first_c90_date, b.first_mm_date
from crab_t20_to_MM as a
left join aa.smm_v4 as b on a.jid=b.jid; quit;

/*---medication code---*/
proc sql;
create table crab_medication_to_MM as
select *
from aa.crab_medication
where jid in (select  jid from aa.smm_v4); quit;

data crab_medication_to_MM; set  crab_medication_to_MM;
drug_date = mdy(substr(recu_fr_dd,5,2), substr(recu_fr_dd,7,2), substr(recu_fr_dd,1,4)); format drug_date yymmdd8.; run;

proc sql;
create table crab_medication_to_MM2 as
select a.*, b.first_c90_date, b.first_mm_date
from crab_medication_to_MM as a
left join aa.smm_v4 as b on a.jid=b.jid; quit;


/*---procedure code---*/
proc sql;
create table crab_procedure_to_MM as
select *
from aa.crab_t30_t20_procedure
where jid in (select  jid from aa.smm_v4); quit;

data crab_procedure_to_MM; set  crab_procedure_to_MM;
proc_date = mdy(substr(recu_fr_dd,5,2), substr(recu_fr_dd,7,2), substr(recu_fr_dd,1,4)); format proc_date yymmdd8.; run;

proc sql;
create table crab_procedure_to_MM2 as
select a.*, b.first_c90_date, b.first_mm_date
from crab_procedure_to_MM as a
left join aa.smm_v4 as b on a.jid=b.jid; quit;





/*--- CRAB의 min_date ---*/
proc sql;
create table diag_filter_CRAB as
select DISTINCT JID, min(dig_date) as first_dig_date format=yymmdd8.
from diag_filter
where dig_date>intnx('month', first_c90_date, 3, 's') and
(  substr(main_sick,1,5) in ("E8352", "M8088") or 
substr(main_sick,1,4) in ("N183", "N184", "N185", "D630", "M484", "M485", "S220", "S221", "S320", "S327", "S720", "S721") or 
substr(main_sick,1,3) in ("T08")  )
group by JID; quit;

proc sql;
create table medi_filter_CRAB as
select DISTINCT JID, min(drug_date) as first_drug_date format=yymmdd8.
from medi_filter
where drug_date>intnx('month', first_c90_date, 3, 's') and
(  div_cd in ("420731BIJ", "420732BIJ", "480330BIJ", "207930BIJ", 
"500334BIJ", "500337BIJ", "500340BIJ", "500341BIJ", "500342BIJ", 
"500343BIJ", "500330BIJ", "500331BIJ", "500333BIJ", "500338BIJ", 
"500336BIJ", "500339BIJ", "459701AGN", "459701ATD", "459702ACH")  )
group by JID; quit;


proc sql;
create table proc_filter_CRAB as
select DISTINCT JID, min(proc_date) as first_proc_date format=yymmdd8.
from proc_filter
where proc_date>intnx('month', first_c90_date, 3, 's') and
(  substr(DIV_CD,1,5) in ("X2021", "X2022", "X2031", 
"X2032", "X2091", "X2092", "X2111", "X2112", "X2131", 
"X2132", "X2512", "X2515", "X1001", "X1002", "X6006", "X6001", "X6002")  )
group by JID; quit;

proc sql;
create table CRAB_min as
select a.JID, a.first_c90_date, a.first_mm_date, a.hyper_3mths_yes, a.renal_3mths_yes, a.ane_3mths_yes, a.bone_3mths_yes, a.mm_outcome, 
b.first_dig_date, c.first_drug_date, d.first_proc_date
from smm_CRAB_after3mths as a
left join diag_filter_CRAB as b on (a.JID=b.JID)
left join medi_filter_CRAB as c on (a.JID=c.JID)
left join proc_filter_CRAB as d on (a.JID=d.JID); quit;

data CRAB_min2; set CRAB_min;
first_CRAB_date = min(first_dig_date, first_drug_date, first_proc_date); format first_CRAB_date yymmdd8.;
run;

proc freq data=CRAB_min2; table mm_outcome; quit; *mm_outcome  1,143;


proc sql;
create table MM_medication as
select MID, JID, DIV_CD, drug_date
from aa.t530_t300_mm_v3
where JID in (select JID from CRAB_min2); quit; *;

proc sql;
create table MM_medication2 as
select a.*, b.first_mm_date
from MM_medication as a left join CRAB_min2 as b on (a.JID=b.JID); quit; *;


/* 약제를 category로 분류 */
proc sql;
create table MM_medication3 as
select *,
case when (  DIV_CD in ('189901ATB')  ) then 1  end as mel_yn,
case when (  DIV_CD in ('463301BIJ', '463302BIJ', '463303BIJ')  ) then 1  end as borte_yn,
case when (  DIV_CD in ('485701ACH', '485702ACH')  ) then 1  end as thali_yn,
case when (  DIV_CD in ('588201ACH', '588201ATB', '588202ACH', '588202ATB', '588203ACH', '588203ATB',
									'588204ACH', '588204ATB', '588205ACH', '588205ATB', '588206ACH', '588206ATB',
									'588207ACH', '588207ATB')  ) then 1  end as lenal_yn
from MM_medication2
where (first_mm_date <= drug_date <= intnx('month', first_mm_date, 2, 's'));
quit;

proc sql;
create table MM_medication4 as
select *,
max(  case when (mel_yn =1) then 1  end  ) as mel_yn1,
max(  case when (borte_yn = 1) then 1  end  ) as borte_yn1,
max(  case when (thali_yn = 1) then 1  end  ) as thali_yn1,
max(  case when (lenal_yn = 1) then 1  end  ) as lenal_yn1
from MM_medication3
group by JID;
quit;

data MM_medication5; set MM_medication4; drop mel_yn borte_yn thali_yn lenal_yn; run;
proc sort data=MM_medication5 nodupkey out=MM_medication_id; by jid; run;


proc sql;
create table MM_medication_id2 as
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
create table MM_medication_id3 as
select *,

case when (mel_only=1) then 1  end as mp,
case when (borte_only=1 or borte_lenal=1) then 1  end as vd,
case when (borte_thali=1 or borte_thali_lenal=1) then 1  end as vtd,

case when (mel_borte=1 or mel_borte_thali=1 or mel_borte_lenal=1) then 1  end as vmp,
case when (mel_thali=1 or mel_lenal=1) then 1  end as other

from MM_medication_id2; quit;


proc sql;
create table aa.smm_CRAB_after3mths  as
select a.*, b.mp, b.vd, b.thali_only, b.lenal_only, b.vmp, b.vtd, b.other
from CRAB_min2  as a left join MM_medication_id3 as b on (a.JID=b.JID); quit;

data aa.smm_CRAB_after3mths; set aa.smm_CRAB_after3mths;

if mm_outcome=. then mm_outcome=0; 

/* MM 약물 */
if mp=. then mp=0;
if vd=. then vd=0; 
if thali_only=. then thali_only=0; 
if lenal_only=. then lenal_only=0; 

if vmp=. then vmp=0; 
if vtd=. then vtd=0; 
if other=. then other=0; 

if hyper_3mths_yes=. then hyper_3mths_yes=0;
if renal_3mths_yes=. then renal_3mths_yes=0;
if ane_3mths_yes=. then ane_3mths_yes=0;
if bone_3mths_yes=. then bone_3mths_yes=0;

run;



/*--- lymphoma ---*/
proc sql;
create table lymphoma as
select *
from aa.t200_2023q4_18
where  substr(main_sick,1,3) in ("C81","C82","C83","C84","C85","C86","E85"); quit;


proc sql;
create table lymphoma_sub as
select JID, RECU_FR_DD, MAIN_SICK
from lymphoma
where JID in (select JID from aa.mgus_to_symMM_v4); quit;

data lymphoma_sub; set lymphoma_sub;
lymp_date = mdy(substr(RECU_FR_DD,5,2), substr(RECU_FR_DD,7,2), substr(RECU_FR_DD,1,4)); format lymp_date yymmdd10.; drop RECU_FR_DD; run;


/* Mgus_to_symMM + lymphoma */
proc sql;
create table mgus_to_symMM_lymp as
select a.*, b.MAIN_SICK, b.lymp_date
from aa.mgus_to_symMM_v4 as a
left join lymphoma_sub as b on (a.JID=b.JID); quit;

/* MM 진단 받은 경우 */
data mgus_to_symMM_lymp; set mgus_to_symMM_lymp;
if first_c90_date ^=.; run;

proc sql;
create table mgus_to_symMM_lymp2 as
select DISTINCT JID, min(lymp_date) as first_lymp_date format=yymmdd10., first_c90_date
from mgus_to_symMM_lymp
where substr(main_sick,1,3) in ("C81","C82","C83","C84","C85","C86","E85") and
lymp_date< first_c90_date
group by JID; quit; *25;


proc sql;
create table mgus_to_symMM_v4_lympex as
select *
from aa.mgus_to_symMM_v4
where JID not in (select JID from mgus_to_symMM_lymp2); quit; *5,475;

proc freq data=mgus_to_symMM_v4_lympex; table mm_outcome; quit; *mm_outcome=1  199;



proc sql;
create table lymp as
select DISTINCT JID, min(lymp_date) as first_lymp_date format=yymmdd10., 1 as lymp_yn
from mgus_to_symMM_lymp
where substr(main_sick,1,3) in ("C81","C82","C83","C84","C85","C86","E85") and
lymp_date>= first_c90_date
group by JID; quit; *;


proc sql;
create table data2 as
select a.*, b.first_lymp_date, b.lymp_yn
from mgus_to_symMM_v4_lympex as a
left join lymp as b on (a.JID=b.JID); quit;

data aa.mgus_to_symMM_v4_lympex; set data2;
if lymp_yn=. then lymp_yn=0;
if death_yn=1 or lymp_yn=1 then cr_event=1;
if cr_event=1 then first_cr_date = min(death_date,first_lymp_date);
if cr_event=. then cr_event=0;
format first_cr_date yymmdd10.;
run;

proc freq data=aa.mgus_to_symMM_v4_lympex; table lymp_yn; quit;

