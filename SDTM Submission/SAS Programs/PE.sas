/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: PE
Programmers: Vasant Raghuraman
Date: May 4, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.PE
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_PE Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=PE)

proc sql;
create table source.PE1RF as
select PE1.*, RFST.RFSTDT
from original.PE as PE1
left join
source.RFSTDTfin as RFST
on PE1.RUSUBJID=RFST.USUBJID;
quit;

data source.PE1RF1(rename=(RUSUBJID=USUBJID));
set source.PE1RF;
if PEDY>0 then PEDT=RFSTDT+PEDY-1;
if PEDY<0 then PEDT=RFSTDT+PEDY;
format PEDT date9.;
PEDTC=put(PEDT,is8601da.);
run;

/*Combine with SV domain to map the right VISITNUM and VISIT for scheduled and unscheduled visits*/
proc sql;
create table source.PE1A as
select PE1RF1.*, SV.VISITNUM as VISITNUM1, SV.VISIT as VISIT1
from source.PE1RF1 as PE1
left join
source.svcombine1 as SV
on PE1.USUBJID=sv.USUBJID and PE1.PEDT>=SV.SVSTDT and PE1.PEDT<=SV.SVENDT and PE1.VISITNUM ne 99
order by USUBJID,VISITNUM1;
quit;

/*Capturing data from suplied source dataset  Original.PE*/

data source.PE2(drop= RSUBJID PEDY VISITNUM1 VISIT1 PEDT RFSTDT);
format STUDYID DOMAIN USUBJID PESEQ PESPID PETESTCD PETEST PECAT PEORRES PESTRESC PEMETHOD VISITNUM VISIT PEDTC;
set source.PE1A;
DOMAIN = "PE";

VISITNUM=VISITNUM1;
VISIT=VISIT1;

if PEDT ne . then PEDTC=put(PEDT,IS8601da.);
else PEDTC="";

VISIT=put(VISITNUM,VISIT.);
PEMETHOD=put(PEMETHOD,$METHOD.);

run;

/*QC1: Check Duplicate values of key variables*/
proc sort data=source.PE2 nodupkey dupout=PE1;
by USUBJID VISITNUM PETESTCD PEDTC PEMETHOD;
run;

data PE1;
set PE1;
Error="Duplicate records for unique combination of key variables";
run;

/*QC2: Check if Visitnum is empty which indicates visit not mapped to SV domain. No action taken as it would be mapped to cycles
in analysis dataset*/
data PE2;
set source.PE2;
if VISITNUM=.;
Error="Alert: VISITNUM not mapped to SV domain";
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.PE;
set EMPTY_PE source.PE2;
run;

**** SORT PE ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=PE) 

proc sort data=target.PE; 
by &PESORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.PE file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\PE.xpt" ; 
run;

