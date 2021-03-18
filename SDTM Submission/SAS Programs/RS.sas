/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: RS
Programmers: Vasant Raghuraman
Date: May 18, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.RS
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_RS Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=RS)

proc sql;
create table source.RSRF as
select LS.*,RFST.RFSTDT
from original.LS as LS
left join
source.RFSTDTFIN as RFST
on LS.RUSUBJID=RFST.USUBJID;
quit;

/*Capturing data from supplied source dataset for VISITNUM = 0 to identify tumors at baseline*/

data source.RS1(rename=(RUSUBJID=USUBJID) DROP=LSTEST LSSEQ LSSPID LSBLFL LSCAT LSLOC LSLOC2 LSSLOC
      LSEVAL LSMETHOD LSDY RSUBJID LSSTRESC LSTESTCD LSORRES LSORRESU LSSTRESN LSSTRESU);
format STUDYID DOMAIN RUSUBJID RSLNKID RSTESTCD RSTEST;
set source.RSRF;
if LSTESTCD = "SYMPDET";
RSORRES=LSORRES;
RSLNKID=LSSPID;
RSSTRESC="PD";
RSTESTCD="NRADPROG";
RSTEST="Non-Radiological Progression";
RSCAT="CLINICAL ASSESSMENT";
RSEVAL=LSEVAL;
RSDY=LSDY;
DOMAIN="RS";

/* To test the proper dates we consider day 1 for all subjects as June 30, 2013 which 1s 19539*/
if RSDY ne . then do;
if RSDY>0 then RSDT=RFSTDT+RSDY-1;
if RSDY<0 then RSDT=RFSTDT+RSDY;
end;
else RSDT = .;

run;

/*Get VISITNUM and VISIT dates from SV domain as it shows VISITNUM 99 i.e. unplanned visit*/

proc sql;
create table source.RS2 as
select RS1.STUDYID, RS1.DOMAIN, RS1.USUBJID, 
       RS1.RSTESTCD, RS1.RSTEST, SV.VISITNUM, SV.VISIT,  RS1.RSORRES, 
       RS1.RSSTRESC, RS1.RSCAT, RS1.RSEVAL, RS1.RSDY, put(RS1.RSDT,date9.) as RSDT, SV.SVSTDT, SV.SVENDT, SV.SVUPDES     
from source.RS1 as RS1
left join
source.svcombine2 as SV
on RS1.USUBJID=SV.USUBJID and RS1.RSDT>=SV.SVSTDT and RS1.RSDT<=SV.SVENDT and SV.SVUPDES="RS";
quit;

proc sort data =source.RS2;
by USUBJID VISITNUM;
run;

data source.RS3(drop=RSDT SVSTDT SVENDT SVUPDES);
format STUDYID DOMAIN USUBJID RSSEQ RSLNKGRP RSTESTCD RSTEST RSCAT RSORRES RSSTRESC RSEVAL VISITNUM VISIT RSDTC RSDY;
set source.RS2;
by USUBJID;
RSLNKGRP=compress("A"||input(substr(USUBJID,16,3),3.));

RSDTC="";

if first.USUBJID then RSSEQ=1;
else RSSEQ=RSSEQ+1;
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.RS;
set EMPTY_RS source.RS3;
run;


**** SORT RS ACCORDING TO METADATA AND SAVE PERMANENT DATASET; 

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=RS) 

proc sort data=target.RS; 
by &RSSORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.RS file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\RS.xpt" ; 
run;
