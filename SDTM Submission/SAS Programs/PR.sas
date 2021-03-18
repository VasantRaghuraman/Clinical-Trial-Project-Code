/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: PR
Programmers: Vasant Raghuraman
Date: May 4, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.PR
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_PR Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=PR)

proc sql;
create table source.SGRF as
select SG.*,RFSTDT
from original.SG as SG
left join
source.RFSTDTFIN as RFST
on SG.RUSUBJID=RFST.USUBJID;
quit;


proc sql;
create table source.RARF as
select RA.*,RFSTDT
from original.RA as RA
left join
source.RFSTDTFIN as RFST
on RA.RUSUBJID=RFST.USUBJID;
quit;



/*Capturing data from suplied source datasets SG and RA*/

data source.PR1(drop=SGBODSYS SGDICTVS SGHLGT SGHLT SGLLT RSUBJID RUSUBJID SGSEQ SGSPID SGCAT SGSCAT SGPRESP
                     SGOCCUR SGDECOD SGDY);
format STUDYID DOMAIN USUBJID PRSEQ PRSPID PRCAT PRSCAT PRPRESP PROCCUR PRTRT;
set source.SGRF;
DOMAIN = "PR";
USUBJID=RUSUBJID;
PRSEQ=SGSEQ;
PRSPID=SGSPID;
PRCAT=SGCAT;
PRSCAT=SGSCAT;
PRPRESP=SGPRESP;
PROCCUR=SGOCCUR;
PRTRT=SGDECOD;
PRSTDY=SGDY;
run;

data source.PR2(drop= RSUBJID RUSUBJID RASEQ RASPID RATRT RACAT RASCAT RAINDC RACUMD RACUMDU RASTDY RAENDY);
format STUDYID DOMAIN USUBJID PRSEQ PRSPID PRTRT PRCAT PRSCAT PRINDC PRDOSE PRDOSU PRSTDY PRENDY;
set source.RARF;
USUBJID=RUSUBJID;
DOMAIN="PR";
PRSEQ=RASEQ;
PRSPID=RASPID;
PRTRT=RATRT;
PRCAT=RACAT;
PRSCAT=RASCAT;
PRINDC=RAINDC;
PRDOSE=input(RACUMD,8.);
PRDOSU=RACUMDU;
PRSTDY=RASTDY;
PRENDY=RAENDY;
run;

data source.PR3(drop=PRSEQ PRSPID PRSTDY PRENDY);
format STUDYID DOMAIN USUBJID PRSEQ1 PRTRT PRCAT PRSCAT PRPRESP PROCCUR PRINDC PRDOSE PRDOSU VISITNUM VISIT PRSTDTC PRENDTC;
retain PRSEQ1;
set source.PR2 source.PR1;
by USUBJID;
PRDOSU =put(PRDOSU,$UNIT.);

if PRSTDY ne . then do;
if PRSTDY>0 then PRSTDT=RFSTDT+PRSTDY-1;
if PRSTDY<0 then PRSTDT=RFSTDT+PRSTDY;
end;
else PRSTDT = .;

if PRENDY ne . then do;
if PRENDY>0 then PRENDT=RFSTDT+PRENDY-1;
if PRENDY<0 then PRENDT=RFSTDT+PRENDY;
end;
else PRENDT = .;

if PRSTDT ne . then PRSTDTC=put(PRSTDT,IS8601da.);
else PRSTDTC="";

if PRENDT ne . then PRENDTC=put(PRENDT,IS8601da.);
else PRENDTC="";

if first.USUBJID then PRSEQ1=1;else PRSEQ1=PRSEQ1+1;
run;

proc sql;
create table source.PR4 as
select PR3.STUDYID, PR3.DOMAIN, PR3.USUBJID, PR3.PRSEQ1, PR3.PRTRT, PR3.PRCAT, PR3.PRSCAT, PR3.PRPRESP, PR3.PROCCUR, 
       PR3.PRINDC, PR3.PRDOSE, PR3.PRDOSU, SV.VISITNUM, SV.VISIT, PR3.PRSTDTC, PR3.PRENDTC
from source.PR3 as PR3
left join
source.svcombine as SV
on PR3.USUBJID=SV.USUBJID and PR3.PRSTDT>=SV.SVSTDT and PR3.PRSTDT<SV.SVENDT
order by 3,4;
quit;


proc sort data=source.PR4;
by USUBJID PRSEQ1 VISITNUM;
run;

proc sort data=source.PR4 nodupkey;
by USUBJID PRSEQ1;
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.PR(drop=PRSEQ1);
set EMPTY_PR source.PR4;
PRSEQ=PRSEQ1;
run;

**** SORT PR ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=PR) 

proc sort data=target.PR; 
by &PRSORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.PR file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\PR.xpt" ; 
run;

