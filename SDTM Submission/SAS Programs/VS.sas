/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: VS
Programmers: Vasant Raghuraman
Date: April 18, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.VS
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_VS Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=VS)

proc sql;
create table source.VSRF as
select VS.*, RFST.RFSTDT
from original.VS as VS
left join
source.RFSTDTFIN as RFST
on VS.RUSUBJID=RFST.USUBJID;
quit;

/*Capturing data from suplied source dataset*/

data source.VS1(rename=(RUSUBJID=USUBJID) drop=RSUBJID VSBLCHG VSBLRES RFSTDT);
set source.VSRF;
VSTESTCD=put(VSTESTCD,$VSTESTCD.);
VSTEST=put(VSTEST,$VSTEST.);
VSORRESU=put(VSORRESU,$UNIT.);
VSSTRESU=put(VSSTRESU,$UNIT.);
VSBLCHGnew=put(VSBLCHG,8.);
VSBLRESnew=put(VSBLRES,8.);


if VSDY ne . then do;
if VSDY>0 then VSDT=RFSTDT+VSDY-1;
if VSDY<0 then VSDT=RFSTDT+VSDY;
end;
else VSDT = .;

run;

/*Get Visitnum and Visit information for the 2 datasets*/
proc sql;
create table source.VS1A as
select VS1.STUDYID, VS1.DOMAIN, VS1.USUBJID, VSSEQ, VSTESTCD, VSTEST, VSORRES, VSORRESU, VSSTRESC, VSSTRESN, VSSTRESU, VSSTAT, VSBLFL, VSDRVFL,
       SV.VISITNUM, SV.VISIT, VSTPT, VSTPTNUM, VSDY, VSBLCHGnew as VSBLCHG label="Baseline Result", 
VSBLRESnew as VSBLRES label="Change From Baseline", VSDT
from source.VS1 as VS1
left join
source.svcombine1 as SV
on VS1.USUBJID=SV.USUBJID and VS1.VSDT>=SV.SVSTDT and VS1.VSDT<=SV.SVENDT;
quit;

proc sort data=source.VS1A out=source.VS1B;
by USUBJID VSSEQ VISITNUM;
run;

proc sort data=source.VS1B nodupkey dupout=VS1C;
by USUBJID VSSEQ;
run;

data source.VS2;
format STUDYID DOMAIN USUBJID VSSEQ VSTESTCD VSTEST VSORRES VSORRESU VSSTRESC VSSTRESN VSSTRESU VSSTAT VSBLFL VSDRVFL
       VISITNUM VISIT VSDTC VSDY VSTPT VSTPTNUM;
set source.VS1B;
       VSDTC="";
run;

proc sql;
create table source.VS3 as
select VS2.STUDYID, VS2.DOMAIN, VS2.USUBJID, VS2.VSSEQ, VSTESTCD, VSTEST, VSORRES, VSORRESU, VSSTRESC, VSSTRESN, VSSTRESU, VSSTAT,
       VSBLFL, VSDRVFL, VISITNUM, VISIT, VSDTC, VSTPT, VSTPTNUM, VSDT, RFST.RFSTDT
from source.VS2 as VS2
left join
source.RFSTDTC as RFST
on VS2.USUBJID=RFST.USUBJID;
quit;

/*Since there are no unplanned visits ie. VISIT 99 and data is collected on protocol planned days, there is no need to
reclassify it according to SVcombine2 domain*/




/*QC Test1: Check for duplicate values of key variables and delete duplicates.Send duplicates to Data Management*/
proc sort data=source.VS2 nodupkey dupout=VS1;
by USUBJID VISITNUM VSDY VSTESTCD;
run;

data VS1;
set VS1;
 Error= "ALERT_R: Duplicate  test results for the same day during the same visit";
run;


/*QC Test2: if SYSBP<DIABP or HEIGHT>300 or WEIGHT>150 in which case there is an error to be sent to Data Management*/

data VS2(keep=USUBJID VISITNUM VSDY VSTESTCD VSTEST VSSTRESN);
set source.VS2;
run;

proc transpose data=VS2 out=VS3;
     id VSTESTCD;
	 idlabel VSTEST;
	 var VSSTRESN;
by USUBJID VISITNUM VSDY;
run;

data vs3;
set vs3;
if DIABP>SYSBP or HEIGHT>300 or WEIGHT>150;
if DIABP>SYSBP then Error="ALERT: Diastolic Blood Pressure Greater than Systolic Blood Pressure";
if WEIGHT>300 then Error="ALERT: Weight outside of normal range";
if HEIGHT>150 then Error="ALERT: Height outside of normal range";
run;

/*QC Test 3: Check if VSSTRESC present but VSORRES not present. VSSTRESU present but VSORRESU not present
VSSTRESC contains numeric but VSSTRESN is not present*/
data VS4 source.VS2;
set source.VS2;
if VSORRES = "" and VSSTRESC ne "" then do;
Error="VSSTRESC present but VSORRES not present";
output VS4;
delete;
end;
if VSORRESU = "" and VSSTRESU ne "" then do;
Error="VSSTRESU present but VSORRESU not present";
output VS4;
delete;
end;
if anyalpha(VSSTRESC) =0 and findc(VSSTRESC,'!"#$%&''()+-')= 0 then do;
 if VSSTRESN eq . and input(VSSTRESC,8.) ne . then do;
Error="ALERT_R: VSSTRESN result is missing while VSSTRESC result has numeric value Requires review";
output vs4;
delete;
end;
end;
output source.VS2;
run;

/*QC Test 4: Check to see if VISITNUM is empty  which indicates Visit is not mapped in SV domain.
As there are some errors in mapping, these shall be dealt with in the analysis. If the dates received were 
a bit more accurate, this process would be easier. However, the issue is mostly not important as the dates will
be part of cycle in the analysis dataset as they lie within start dates of two cycles*/

data vs5;
set source.VS2;
if VISITNUM=.;
format VSDT date9.;
run;


/* Since there are no errors, no observations were deleted from source.VS2*/

data target.VS(drop=VSBLCHG VSBLRES VSDT Error);
set Empty_VS Source.VS2;
run;

/*For SUPPDS calculation*/

data source.VS1;
set source.VS2;
label VSBLCHG="Change From Baseline" VSBLRES="Baseline Result";
run;

%SUPPDOMAIN(dmname=VS)

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.VS file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\VS.xpt" ; 
run;

proc cport data=target.SUPPVS file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPVS.xpt" ; 
run;
