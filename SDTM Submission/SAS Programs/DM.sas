/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: DM
Programmers: Vasant Raghuraman
Date: June 20, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.DM
************************************************************************************************/
%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_DM Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=DM)

/*Capturing data from supplied source dataset for VISITNUM = 0 to identify tumors at baseline*/

data source.DM1(rename=(RUSUBJID=USUBJID RSUBJID=SUBJID) drop=RFSTTM RFENTM RFSTDY RFENDY);
format STUDYID DOMAIN RUSUBJID RSUBJID RFSTDTC SITEID AGE AGEU SEX RACE COUNTRY;
set Original.DM;

AGE=input(AGEC,8.);

COUNTRY="";
SITEID="";
AGEU=put(AGEU,AGEU.);
RACE=put(RACE,RACE.);
SEX=put(SEX,SEX.);

run;

/*From this we can get RFSTDTC RFENDTC*/
data DMEX1(keep=USUBJID EXSTDTM EXSTDT EXENDTM EXENDT EPOCHNUM EXTPTNUM EXTRT);
set target.EX;
%dtc2dt(EXSTDTC,prefix=EXST);
%dtc2dt(EXENDTC,prefix=EXEN);
EPOCHNUM=input(compress(EPOCH,,"as"),8.);
run;

proc sql;
create table DMEX2 as
select USUBJID, min(EXSTDTM) as RFSTDTM, min(EXSTDT) as RFSTDT,  
       EPOCHNUM, EXTPTNUM 
from work.DMEX1 as EX
where EPOCHNUM=1 and EXTPTNUM=1
group by USUBJID, EPOCHNUM, EXTPTNUM;
quit;

data DMEX3(keep=USUBJID EXENDTM EXENDT EPOCHNUM EXTPTNUM rename=(EXENDTM=RFENDTM EXENDT=RFENDT));
set DMEX1;
by USUBJID EPOCHNUM EXTPTNUM;
if last.USUBJID and last.EPOCHNUM and last.EXTPTNUM;
run;

data source.RFSTDTfin;
length RFSTDTC RFENDTC $16;
merge DMEX2 DMEX3;
by USUBJID;
if (RFSTDT < datepart(RFSTDTM) and RFSTDT ne .) or RFSTDTM=. then RFSTDTC=put(RFSTDT,IS8601da.);
else RFSTDTC=put(RFSTDTM,IS8601dt.);
if RFENDT > datepart(RFENDTM) or RFENDTM=. then RFENDTC=put(RFENDT,IS8601da.);
else RFENDTC=put(RFENDTM,IS8601dt.);
run;

/*From this we can get RFXSTDTC RFXENDTC*/
data DMSE1(keep=USUBJID SESTDT SEENDT TAETORD EPOCH);
set target.SE;
%dtc2dt(SESTDTC,prefix=SEST);
%dtc2dt(SEENDTC,prefix=SEEN);
run;

proc sql;
create table DMSE2 as
select USUBJID, min(TAETORD) as MINTAETORD, max(TAETORD) as MAXTAETORD, SESTDT, SEENDT, TAETORD, EPOCH
from work.DMSE1 as DMSE1
where EPOCH not in("SCREENING","FOLLOW-UP")
group by USUBJID
order by USUBJID, TAETORD;
quit;

/*From this we can get RFICDTC RFPENDTC DTHDTC*/
data DMDS1(keep=USUBJID DSSCAT DSSTDTC);
set target.DS;
run;

proc transpose data=DMDS1 out=DMDS2;
               id DSSCAT;
			   var DSSTDTC;
			   by USUBJID;
run;

data DMDS3;
set DMDS2;
if DEATH ne "" then RFPENDTC = DEATH;
if DEATH = "" and LAST_CONTACT ne "" then RFPENDTC = LAST_CONTACT;
if DEATH = "" and LAST_CONTACT = "" and END_OF_TREATMENT ne "" then RFPENDTC = END_OF_TREATMENT;
if DEATH = "" and LAST_CONTACT = ""and END_OF_TREATMENT = "" and PREMATURE_TREATMENT_DISCONTINUAT ne "" then RFPENDTC = PREMATURE_TREATMENT_DISCONTINUAT;
if DEATH = "" and LAST_CONTACT = ""and END_OF_TREATMENT = "" and PREMATURE_TREATMENT_DISCONTINUAT = "" then RFPENDTC = "";
run;

/*From the SS Domain we can get DTHFL to account for AE domain*/
data DMSS1(keep=USUBJID DTHFL);
set target.SS;
if SSORRES="DEATH" then DTHFL="Y";
else do;
DTHFL="";
delete;
end;
run;

proc sql;
create table source.DM2 as
select DM1.STUDYID, DM1.DOMAIN, DM1.USUBJID, DM1.SUBJID,
       (select RFST.RFSTDTC from source.RFSTDTfin as RFST where DM1.USUBJID=RFST.USUBJID ) as RFSTDTC,      
       (select RFST.RFENDTC from source.RFSTDTfin as RFST where DM1.USUBJID=RFST.USUBJID ) as RFENDTC,
       (select RFST.RFSTDTC from source.RFSTDTfin as RFST where DM1.USUBJID=RFST.USUBJID ) as RFXSTDTC,
       (select RFST.RFENDTC from source.RFSTDTfin as RFST where DM1.USUBJID=RFST.USUBJID) as RFXENDTC,
	   (select DMDS3.INFORMED_CONSENT from work.DMDS3 as DMDS3 where DM1.USUBJID=DMDS3.USUBJID) as RFICDTC,
	   (select DMDS3.RFPENDTC from work.DMDS3 as DMDS3 where DM1.USUBJID=DMDS3.USUBJID ) as RFPENDTC,
	   (select DMDS3.DEATH from work.DMDS3 as DMDS3 where DM1.USUBJID=DMDS3.USUBJID) as DTHDTC,
	   (select DMSS1.DTHFL from work.DMSS1 as DMSS1 where DM1.USUBJID=DMSS1.USUBJID) as DTHFL,
        AGE, AGEU, SEX, RACE, COUNTRY, 
       (select Strat.ARMCD from source.Strat as Strat where DM1.USUBJID=Strat.USUBJID) as ARMCD,
       (select Strat.ARM from source.Strat as Strat where DM1.USUBJID=Strat.USUBJID) as ARM,
	   (select Strat.ACTARMCD from source.Strat as Strat where DM1.USUBJID=Strat.USUBJID) as ACTARMCD,
	   (select Strat.ACTARM from source.Strat as Strat where DM1.USUBJID=Strat.USUBJID) as ACTARM,
        DM1.AGEGRP, DM1.EXPOSED, DM1.FSTPAT, DM1.ITT, DM1.RACEC, DM1.RANDOM, DM1.SAFETY, DM1.REGION, DM1.AGEC
from source.DM1 as DM1;
quit;

data source.DM3;
format STUDYID DOMAIN USUBJID SUBJID RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFICDTC RFPENDTC DTHDTC DTHFL AGE AGEU SEX RACE COUNTRY
       ARMCD ARM ACTARMCD ACTARM AGEGRP EXPOSED FSTPAT ITT RACEC RANDOM SAFETY REGION AGEC;
set source.DM2;
run;

proc sql;
create table NOTTRT as
select USUBJID
from source.DM3 as DM3
except
select USUBJID
from target.EX as EX;
quit;

proc sql;
create table source.DM4 as
select STUDYID, DOMAIN, DM3.USUBJID as USUBJID, NOTTRT.USUBJID as USUBJID1, SUBJID, RFSTDTC, RFENDTC, RFXSTDTC, RFXENDTC, RFICDTC, RFPENDTC, DTHDTC, DTHFL, AGE, AGEU, SEX, RACE, COUNTRY,
       ARMCD, ARM, ACTARMCD, ACTARM, AGEGRP, EXPOSED, FSTPAT, ITT, RACEC, RANDOM, SAFETY, REGION, AGEC
from source.DM3 as DM3
left join
work.NOTTRT as NOTTRT
on DM3.USUBJID=NOTTRT.USUBJID;
quit;

data source.DM5(drop=USUBJID1);
set source.DM4;
if USUBJID1 ne "" then do;
ACTARMCD="NOTTRT";
ACTARM="Not Treated";
RFXSTDTC="";
RFXENDTC="";
RFSTDTC="";
RFENDTC="";
end;
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.DM(drop=AGEGRP EXPOSED FSTPAT ITT RACEC RANDOM SAFETY REGION AGEC);
set EMPTY_DM source.DM5;
run;


**** SORT DM ACCORDING TO METADATA AND SAVE PERMANENT DATASET; 

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=DM) 

proc sort data=target.DM; 
by &DMSORTSTRING; 
run;


/*Find out which variables are required for the SUPPDM dataset*/

proc transpose data = target.DM(obs=0) out=source.DM9;
var _all_;
run;

proc sql noprint;
 select _name_ into : list separated by ' '
  from source.DM9;
quit;

data _null_;
%put &list;
run;

/*Get the variables from source.DM1 to DM10*/
proc transpose data = source.DM5(obs=0) out=source.DM10;
var _all_;
run;

proc sql noprint;
 select _name_ into : list separated by ' '
  from source.DM10;
quit;

data _null_;
%put &list;
run;

/*Compare all the variables of DM according to variables in DM9 to DM10 to see which variables need to be removed to create SUPPDM dataset*/

proc sql;
create table source.DM11 as
select _NAME_ from source.DM10
except 
select _NAME_ from source.DM9;
quit;

proc sql noprint;
 select _NAME_ into : list separated by ' '
  from source.DM11;
quit;

data _null_;
%put &list;
run;


/*Transfer SUPPDM variables to Excel file to input metadata*/
PROC EXPORT DATA= SOURCE.DM11 
            OUTFILE= "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\DM11.csv" 
            DBMS=CSV LABEL REPLACE;
     PUTNAMES=YES;
RUN;


/*Create SuppDM Domain*/

%SUPPDOMAIN(dmname=DM)

/*Since in the DM domain there is only one record per USUBJID, IDVAR and IDVARVAL are NULL*/
data source.dm1;
set source.dm5;
run;

data source.suppdm1(drop=IDVARVAL);
set target.suppdm;
IDVAR="";
run;

data target.suppdm;
format STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM QLABEL QVAL QORIG QEVAL;
set source.suppdm1;
IDVAR="";
IDVARVAL="";
label IDVARVAL="Identifying Variable Value";
run;


/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.DM file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\DM.xpt" ; 
run;

proc cport data=target.SUPPDM file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPDM.xpt" ; 
run;
