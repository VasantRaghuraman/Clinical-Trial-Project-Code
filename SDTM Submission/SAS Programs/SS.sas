/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: SS
Programmers: Vasant Raghuraman
Date: April 24, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.SS
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_SS Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=SS)

proc sql;
create table source.SS1 as
select USUBJID, AEENDY as SSDY
from target.AE as AE
where AESDTH="Y";
quit;

proc sql;
create table source.SS2 as 
select distinct USUBJID, DSSCAT as SSORRES label="Result or Finding Original Result", 
                DSDECOD as SSCAT label="Category for Assessment"
from target.DS as DS
where DS.DSSCAT="DEATH";
quit;

data source.SS3;
merge source.SS1 source.SS2;
by USUBJID;
run;

proc sql;
create table source.SS3a as
select ss3.USUBJID,ss3.SSDY,put((case when SSDY>=0 then RFSTDT+SSDY-1
                      else RFSTDT+SSDY end),IS8601da.) as SSDTC,
							(case when SSDY>=0 then RFSTDT+SSDY-1
                      else RFSTDT+SSDY end) as SSDT,ss3.SSORRES,ss3.SSCAT
from source.ss3 as SS3
left join 
source.RFSTDTFIN as RFST
on SS3.USUBJID=RFST.USUBJID;
quit;

/*As per protocol, survival status is checked prior to the beginning of each cycle. 
Hence the study day of end of VISIT in SV domain is considered for SSDY and SSDTC. Since data for this
has not been collected, it can be imputed in analyis dataset only*/
data source.SVDT(keep=STUDYID DOMAIN USUBJID VISITNUM VISIT SVENDY RFSTDT);
merge source.svcombine source.RFSTDTC;
by USUBJID; 
run;

data source.SVDT1(keep=STUDYID DOMAIN USUBJID VISITNUM VISIT SSDY SSDTC SSORRES);
set source.SVDT;
if SVENDY>=0 then SSDT=RFSTDT+SVENDY-1;
else SSDT=RFSTDT+SVENDY;
SSDTC=put(SSDT,IS8601da.);
SSORRES="";
if SSDT>=RFSTDT then SSDY=SSDT-RFSTDT+1;
else SSDY=SSDT-RFSTDT;
run;

data source.ss3b;
set source.ss3a source.SVDT1;
if SSORRES="DEATH" then srtnum=1; else srtnum=0;
run; 

proc sort data=source.Ss3b;
by USUBJID srtnum VISITNUM;
run;

data source.SS4(drop=SSDT SRTNUM);
format STUDYID DOMAIN USUBJID SSSEQ SSTESTCD SSTEST SSCAT SSORRES SSSTRESC VISITNUM VISIT SSDTC SSDY;
retain SSSEQ;
set source.SS3B;
by USUBJID;
STUDYID="EFC10547";
DOMAIN="SS";
SSTESTCD="SURVSTAT";
SSTEST="Survival Status";
SSSTRESC=put(SSORRES,$SSSTRESC.);
if first.USUBJID then SSSEQ=1;
else SSSEQ=SSSEQ+1;
label SSDY="Study Day of Assessment";
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.SS;
set EMPTY_SS source.SS4;
run;

/*Data already sorted. Hence not sorted here*/
**** SORT SS ACCORDING TO METADATA AND SAVE PERMANENT DATASET;
/*
%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=SS) 

proc sort data=target.SS; 
by &SSSORTSTRING; 
run;
*/

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.SS file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SS.xpt" ; 
run;
