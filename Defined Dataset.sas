libname aa '/vol/userdata14/sta_room462' ;


/****************************** T530과 T300과 join한다. ******************************/
/* v3 */

data t300_mm; set aa.T300_2023Q4_18;
where div_cd in ('189901ATB', '463301BIJ', '463302BIJ', '463303BIJ', '485701ACH', '485702ACH',
									'588201ACH', '588201ATB', '588202ACH', '588202ATB', '588203ACH', '588203ATB',
									'588204ACH', '588204ATB', '588205ACH', '588205ATB', '588206ACH', '588206ATB',
									'588207ACH', '588207ATB');
keep mid jid div_cd; run;

proc sql;
create table t300_t200_mm as
select a.*, b.recu_fr_dd, b.pat_age as drug_age
from t300_mm as a left join aa.t200_2023Q4_18 as b on a.mid=b.mid; quit;


data t530_mm; set aa.t530_2023Q4_18;
where div_cd in ('189901ATB', '463301BIJ', '463302BIJ', '463303BIJ', '485701ACH', '485702ACH',
									'588201ACH', '588201ATB', '588202ACH', '588202ATB', '588203ACH', '588203ATB',
									'588204ACH', '588204ATB', '588205ACH', '588205ATB', '588206ACH', '588206ATB',
									'588207ACH', '588207ATB');
keep mid jid div_cd; run;

proc sql;
create table t530_t200_mm as
select a.*, b.recu_fr_dd, b.pat_age as drug_age
from t530_mm as a left join aa.t200_2023Q4_18 as b on a.mid=b.mid; quit;


/* T530 mm + T300 mm*/
proc sql;
create table aa.t530_t300_mm_v3 as
select * 
	from t530_t200_mm
		union all
select *
	from t300_t200_mm ;
quit; 

data aa.t530_t300_mm_v3; set aa.t530_t300_mm_v3;
drug_date = input(recu_fr_dd, yymmdd10.);
format drug_date yymmdd10.;
drop recu_fr_dd; run;

proc sort data=aa.t530_t300_mm_v3; by jid drug_date; run;

/************************************************************************/

/*** last dig date 정의 ***/

proc sql;
create table aa.last_dig_date as
select jid, max(recu_to_dd) as tmp
from aa.t200_2023q4_18
group by jid; quit;

/* last_dig_date를 date format으로 정의 */
data aa.last_dig_date; set aa.last_dig_date;
last_dig_date= input(tmp , yymmdd10.);
format last_dig_date yymmdd10.;
drop tmp; run;


/*** 3. 사망 정의 ***/

proc sql;
create table aa.dgrslt_tp_cd_2_id as
select jid,
max( case when (dgrslt_tp_cd='4') then 1 end ) as dgrslt_tp_cd_2
from aa.t200_2023q4_18
group by jid; quit;