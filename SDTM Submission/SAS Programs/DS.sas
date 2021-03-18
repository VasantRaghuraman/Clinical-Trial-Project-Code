/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: DS
Programmers: Vasant Raghuraman
Date: April 5, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.DS
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_DS Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=DS)

/*Capturing data from suplied source dataset. DSTERM is assumed to be DSDECOD as it was redacted*/

/* To test the proper dates we consider day 1 for all subjects as June 30, 2013 which 1s 19539*/


data _null_;
var=put(19539,date9.);
put "The date 19539 is:" var;
run;

proc sql;
create table source.DSRF as
select DS.*,RFST.RFSTDT
from original.DS as DS
left join
source.RFSTDTFIN as RFST
on DS.RUSUBJID=RFST.USUBJID;
quit;


data source.DS1(rename=(RUSUBJID=USUBJID) drop=DSSTHWK DSSTDTM DSSTTM DSSTDY RFSTDT);
set source.DSRF;
DSTERM=DSDECOD;
label DSTERM="Reported Term for the Disposition Event";
if dsstdy=. then dsstdy=dssthwk*7;

if DSSTDY ne . then do;
if DSSTDY>0 then DSSTDT=RFSTDT+DSSTDY-1;
if DSSTDY<0 then DSSTDT=RFSTDT+DSSTDY;
end;
else DSSTDT = .;
format dsstdt date9.;

if DSSTTM ne . then DSSTDTM=dhms(DSSTDT,0,0,DSSTTM);

if DSSTDT ne . then do;
	if DSSTTM ne . then DSSTDTC=put(DSSTDTM,IS8601dT.);
	else DSSTDTC=put(DSSTDT,IS8601da.);
end;
else DSSTDTC="";

run;

/*Separate Unsceduled observations*/
data source.DS1A source.DS1B;
set source.DS1;
if VISITNUM=99 then output source.DS1B;
else output source.DS1A;
run;

data source.SVcombine;
set target.SV;
%dtc2dt(SVSTDTC , prefix=SVST);
%dtc2dt(SVENDTC , prefix=SVEN);
run;

data source.svcombine1 source.svcombine2;
set source.svcombine;
if mod(VISITNUM,1)=0 then output source.svcombine1;
else output source.svcombine2;
run;


proc sql;
create table source.DS2a as
select DS1A.STUDYID, DS1A.DOMAIN, DS1A.USUBJID, DS1A.DSSEQ, DS1A.DSTERM, DS1A.DSDECOD, DS1A.DSCAT, 
       DS1A.DSSCAT, DS1A.VISITNUM, DS1A.VISIT, DS1A.DSSTDT, DS1A.DSSTDTC, 
       SV.VISITNUM as VISITNUMNEW label="New VISITNUM", SV.VISIT as VISITNEW label="NEW VISIT",sv.SVUPDES
from source.DS1A as DS1A 
left join
source.svcombine1 as SV
on DS1A.USUBJID=SV.USUBJID and SV.VISITNUM<92 and DS1A.DSSTDT>=sv.SVSTDT and DS1A.DSSTDT<=sv.SVENDT
order by USUBJID,DSSEQ;
quit;
 
data source.DS2b(drop=VISITNUMNEW VISITNEW);
set source.DS2A;
if VISITNUMnew =. and VISITNUM ne . and DSSTDT=. then do;
VISITNUMnew=VISITNUM;
VISITNEW=compbl("VISIT "||VISITNUMNEW);
end;
VISITNUM=VISITNUMNEW;
VISIT=VISITNEW;
run;


proc sql;
create table source.DS2C as
select DS1B.STUDYID, DS1B.DOMAIN, DS1B.USUBJID, DS1B.DSSEQ, DS1B.DSTERM, DS1B.DSDECOD, DS1B.DSCAT, 
       DS1B.DSSCAT, DS1B.VISITNUM, DS1B.VISIT, DS1B.DSSTDT, DS1B.DSSTDTC, 
       SV.VISITNUM as VISITNUMNEW label="NEW VISITNUM",SV.VISIT as VISITNEW label="NEW VISIT", sv.SVUPDES
from source.DS1B as DS1B
left join
source.svcombine2 as SV
on DS1B.USUBJID=SV.USUBJID and DS1B.DSSTDT>=sv.SVSTDT and DS1B.DSSTDT<=sv.SVENDT and sv.SVUPDES="DS"
order by USUBJID,DSSEQ;
quit;

data source.DS2D(drop=VISITNUMNEW VISITNEW);
set source.DS2C;
if VISITNUMnew =. and VISITNUM ne . and DSSTDT=. then do;
VISITNUMnew=VISITNUM;
VISITNEW=compbl("VISIT "||VISITNUMNEW);
end;
VISITNUM=VISITNUMNEW;
VISIT=VISITNEW;
run;

data source.DS2E;
set source.DS2B source.DS2D;
run;

proc sort data=source.DS2E;
by USUBJID DSSEQ;
run;


/*Add Controlled Terminology and get TAETORD to obtain EPOCH in step below*/
data source.DS4(drop=VISITNUM VISIT);
set source.DS2E;
if VISITNUM<80 then TAETORD=int(VISITNUM+1);
if visitnum>=80 then TAETORD=int(VISITNUM-59);
DSDECOD=put(DSDECOD, NCOMPLT.);
DSCAT=put(DSCAT, DSCAT.);
run;

/*Add Epoch variable*/
proc sql;
create table source.DS5 as
select DS4.STUDYID, DS4.DOMAIN, DS4.USUBJID, DS4.DSSEQ, DS4.DSTERM, DS4.DSDECOD, DS4.DSCAT, 
       DS4.DSSCAT, DS4.DSSTDTC, TA.EPOCH
from source.DS4 as DS4
left join
target.TA as TA
on DS4.TAETORD = TA.TAETORD and ARMCD contains "PLACEBO" and DS4.DSCAT ne "PROTOCOL MILESTONE"
order by 1,2,3,4;
quit;

/*QC1 for DS domain*/

data inf_consent(keep = studyid usubjid rficdt);
 set source.ds5;
 by studyid usubjid;
 if upcase((scan(dsscat,1," "))) = "INFORMED"
 and upcase(dscat) = "PROTOCOL MILESTONE"
 and upcase(dsdecod) = "ELIGIBLE";
 if missing(dsstdtc) then
 Error= "WARNING: Missing date of Inform Consent in DS";
 else if length(dsstdtc) < 10 then
 Error= "WARNING: Date of Inform Consent is partial";
 else rficdt = input(dsstdtc,is8601da.);
 run;

 /*QC2 for DS domain*/

 data randomiz;
 set source.ds5;
 by studyid usubjid;
 if upcase(dsdecod) = “RANDOMIZATION”;
/*in case of improper coding please check exact value of DSDECOD*/
 if missing(dsstdtc) then 
 Error= "WARNING: Has the subject been randomized? Please check!";
 else if length(dsstdtc)<10 then
Error= "WARNING: Date of Randomization is partial. Please check";
 else rficdt = input(dsstdtc,is8601da.);
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.DS;
set Empty_DS source.DS5;
run;

**** SORT DS ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=DS) 

proc sort data=target.DS; 
by &DSSORTSTRING; 
run;



/*Find out which variables are required for the SUPPDS dataset*/

proc transpose data = target.DS(obs=0) out=source.DS6;
var _all_;
run;

proc sql noprint;
 select _name_ into : list separated by ' '
  from source.DS6;
quit;

data _null_;
%put &list;
run;

/*Get the variables from source.DS1 to DS7*/
proc transpose data = source.DS1(obs=0) out=source.DS7;
var _all_;
run;

proc sql noprint;
 select _name_ into : list separated by ' '
  from source.DS7;
quit;

data _null_;
%put &list;
run;

/*Compare all the variables of DS according to variables in DS6 to DS7 to see which variables need to be removed to create SUPPDS dataset*/

proc sql;
create table source.DS8 as
select _NAME_ from source.DS7
except 
select _NAME_ from source.DS6;
quit;

proc sql noprint;
 select _NAME_ into : list separated by ' '
  from source.DS8;
quit;

data _null_;
%put &list;
run;


/*Transfer SUPPDS variables to Excel file to input metadata*/
PROC EXPORT DATA= SOURCE.DS8 
            OUTFILE= "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\DS8.csv" 
            DBMS=CSV LABEL REPLACE;
     PUTNAMES=YES;
RUN;

/*Create SuppDS Domain*/

%SUPPDOMAIN(dmname=DS)


/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.DS file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\DS.xpt" ; 
run;

proc cport data=target.SUPPDS file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPDS.xpt" ; 
run;
