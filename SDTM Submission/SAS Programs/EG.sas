/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: EG
Programmers: Vasant Raghuraman
Date: April 5, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.EG
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_EG Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=EG)

/*Capturing data from suplied source dataset*/

data source.EG1(rename=(RUSUBJID=USUBJID));
set Original.EG;
EGSTRESC=put(EGSTRESC,$EGSTRESC.);
EGTESTCD=put(EGTESTCD,$EGTESTCD.);
EGTEST=put(EGTEST,$EGTEST.);

run;


proc sql;
create table source.EG1RF as
select EG1.STUDYID, EG1.DOMAIN, EG1.USUBJID, EG1.EGSEQ, EG1.EGTESTCD, EG1.EGTEST, EG1.EGORRES, EG1.EGSTRESC, EG1.EGBLFL,
       EG1.VISITNUM, EG1.VISIT, EG1.EGCLSIG, EG1.EGDY, RFST.RFSTDT
from source.EG1 as EG1
left join
source.RFSTDTfin as RFST
on EG1.USUBJID=RFST.USUBJID;
quit;

data source.EG1RF1;
set source.EG1RF;
if EGDY>0 then EGDT=RFSTDT+EGDY-1;
if EGDY<0 then EGDT=RFSTDT+EGDY;
format EGDT date9.;
EGDTC=put(EGDT,is8601da.);
run;


/*Combine with SV domain to map the right VISITNUM and VISIT for scheduled and unscheduled visits*/
proc sql;
create table source.EG1A as
select EG1.STUDYID, EG1.DOMAIN, EG1.USUBJID, EG1.EGSEQ, EG1.EGTESTCD, EG1.EGTEST, EG1.EGORRES, EG1.EGSTRESC, EG1.EGBLFL,
       EG1.VISITNUM, EG1.VISIT, SV.VISITNUM as VISITNUM1, SV.VISIT as VISIT1, EG1.EGCLSIG, EG1.EGDY, EG1.EGDT, EG1.EGDTC
from source.EG1RF1 as EG1
left join
source.svcombine1 as SV
on EG1.USUBJID=sv.USUBJID and EG1.EGDT>=SV.SVSTDT and EG1.EGDT<=SV.SVENDT and EG1.VISITNUM ne 99
order by USUBJID,VISITNUM,EGSEQ;
quit;

proc sql;
create table source.EG1B as
select EG1A.STUDYID, EG1A.DOMAIN, EG1A.USUBJID, EG1A.EGSEQ, EG1A.EGTESTCD, EG1A.EGTEST, EG1A.EGORRES, EG1A.EGSTRESC, EG1A.EGBLFL,
       EG1A.VISITNUM, EG1A.VISIT, EG1A.VISITNUM1, EG1A.VISIT1, SV.VISITNUM as VISITNUM2, SV.VISIT as VISIT2, EG1A.EGCLSIG, EG1A.EGDY, EG1A.EGDT,
	   EG1A.EGDTC
from source.EG1A as EG1A
left join
source.svcombine2 as SV
on EG1A.USUBJID=sv.USUBJID and EG1A.EGDT>=SV.SVSTDT and EG1A.EGDT<=SV.SVENDT and EG1A.VISITNUM = 99 and SV.SVUPDES="EG"
order by USUBJID,VISITNUM,EGSEQ;
quit;

data source.EG1C(drop=VISITNUM1 VISITNUM2 VISIT1 VISIT2 EGDT);
set source.EG1B;
if VISITNUM1 ne . then VISITNUM=VISITNUM1;
if VISIT1 ne "" then VISIT=VISIT1;
if VISITNUM2 ne . then VISITNUM=VISITNUM2;
if VISIT2 ne "" then VISIT=VISIT2;

run;

/*QC1: Check Duplicate values of key variables*/
proc sort data=source.EG1C nodupkey dupout=EG1;
by USUBJID VISITNUM EGTESTCD EGDTC;
run;

data EG1;
set EG1;
Error="Duplicate records for unique combination of key variables";
run;

/*QC2: Check if Visitnum is empty which indicates visit not mapped to SV domain*/
data EG2;
set source.EG1C;
if VISITNUM=.;
Error="Alert: VISITNUM not mapped to SV domain";
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.EG(drop=EGCLSIG);
set EMPTY_EG source.EG1C;
run;

**** SORT EG ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=EG) 

proc sort data=target.EG; 
by &EGSORTSTRING; 
run;

/*Find out which variables are required for the SUPPEG dataset*/

proc transpose data = target.EG(obs=0) out=source.EG5;
var _all_;
run;

proc sql noprint;
 select _name_ into : list separated by ' '
  from source.EG5;
quit;

data _null_;
%put &list;
run;

/*Get the variables from source.EG1 to EG6*/
proc transpose data = source.EG1(obs=0) out=source.EG6;
var _all_;
run;

proc sql noprint;
 select _name_ into : list separated by ' '
  from source.EG6;
quit;

data _null_;
%put &list;
run;

/*Compare all the variables of EG according to variables in EG5 to EG5 to see which variables need to be removed to create SUPPEG dataset*/

proc sql;
create table source.EG7 as
select _NAME_ from source.EG6
exEGpt 
select _NAME_ from source.EG5;
quit;

proc sql noprint;
 select _NAME_ into : list separated by ' '
  from source.EG7;
quit;

data _null_;
%put &list;
run;


/*Transfer SUPPEG variables to ExEGl file to input metadata*/
PROC EXPORT DATA= source.EG7 
            OUTFILE= "D:\Pancrea_SanofiU_2007_134\SDTM Submission\ExEGl Files\EG7.csv" 
            DBMS=CSV LABEL REPLACE;
     PUTNAMES=YES;
RUN;

/*Create SuppEG Domain*/

%SUPPDOMAIN(dmname=EG)

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.EG file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\EG.xpt" ; 
run;

proc cport data=target.SUPPEG file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPEG.xpt" ; 
run;
