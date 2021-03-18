/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: QS
Programmers: Vasant Raghuraman
Date: April 18, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.QS
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_QS Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=QS)

/*Capturing data from suplied source dataset*/

data source.QS1(rename=(RUSUBJID=USUBJID) drop=RSUBJID QSBLCHG QSBLRES);
set Original.QS;
QSTESTCD=put(QSTESTCD,$QSTESTCD.); 
QSTEST=put(QSTEST, $QSTEST.); 
QSCAT=put(QSCAT, $QSCAT.); 
QSORRESU=put(QSORRESU, $UNIT.);
QSSTRESU=put(QSSTRESU, $UNIT.);
QSBLCHGnew=input(QSBLCHG,8.);
QSBLRESnew=input(QSBLRES,8.);

run;

proc sql;
create table source.QS1RF as
select QS1.*,RFST.RFSTDT
from source.QS1 as QS1
left join
source.RFSTDTFIN as RFST
on QS1.USUBJID=RFST.USUBJID;
quit;

data source.QS1RF1(drop=RFSTDT);
set source.QS1RF;
if QSDY ne . then do;
if QSDY>0 then QSDT=RFSTDT+QSDY-1;
if QSDY<0 then QSDT=RFSTDT+QSDY;
end;
else QSDT = .;
run;

/*Get VISITNUM and VISIT from SV domain*/

proc sql;
create table source.QS1A as
select QS1.STUDYID, QS1.DOMAIN, QS1.USUBJID, QS1.QSSEQ, QS1.QSTESTCD, QS1.QSTEST, QS1.QSCAT, QS1.QSORRES, QS1.QSORRESU, QS1.QSSTRESC, QS1.QSSTRESN,
       QS1.QSSTRESU, QS1.QSSTAT, QS1.QSBLFL, SV.VISITNUM, SV.VISIT, QS1.QSTPT, QS1.QSTPTNUM, QS1.QSORRESN, QSDY,QSDT,
	   QSBLCHGnew as QSBLCHG label="Change From Baseline", QSBLRESnew as QSBLRES label="Baseline Result"
from source.QS1RF1 as QS1
left join
source.SVcombine1 as SV
on QS1.USUBJID=SV.USUBJID and QS1.QSDT>=SV.SVSTDT and QS1.QSDT<=SV.SVENDT;
quit;

/*As one row is duplicated by join, it is removed as below*/

proc sort data=source.QS1A nodupkey;
by USUBJID QSSEQ;
run;

proc sort data=source.QS1A out=source.QS1B;
by USUBJID QSTESTCD VISITNUM QSDY;
run;

/*Pain Intensity (PI):Questionnaire Supplement to the Study Data Tabulation Model Implementation Guide for Human Clinical Trials*/
data source.QS2(drop=QSSEQ);
format USUBJID QSSEQnew;
retain QSSEQnew;
set source.QS1B;
by USUBJID QSTESTCD VISITNUM QSDY;
if first.USUBJID then QSSEQnew=1;
if not(first.USUBJID)  then QSSEQnew=QSSEQnew+1;
RNGTXTLO="NO PAIN";
RNGTXTHI="WORST PAIN IMAGINABLE";
RNGVALLO=0;
RNGVALHI=100;
QSMETHOD="VISUAL ANALOG SCALE 100mm";
QSEVLINT="-PT24H";
label RNGTXTLO="Range Text Lo" RNGTXTHI="Range Text Hi" RNGVALLO="Range Value Lo" 
      RNGVALHI="Range Value HI" QSMETHOD="Method Of Measurement";
QSSTRESN=input(QSSTRESC,8.);
run;

data source.QS2A(drop=QSSEQnew);
set source.QS2;
QSSEQ=QSSEQnew;
run;

data source.QS3(DROP=RNGTXTLO RNGTXTHI RNGVALLO RNGVALHI QSBLCHG QSBLRES QSMETHOD QSDT QSORRESN);
format STUDYID DOMAIN USUBJID QSSEQ QSTESTCD QSTEST QSCAT QSORRES QSORRESU QSSTRESC QSSTRESN QSSTRESU QSSTAT QSBLFL
       VISITNUM VISIT QSDTC QSDY QSTPT QSTPTNUM QSEVLINT;
set source.QS2A;
QSDTC="";
run;

/*QC 1: Check for duplicate values of key variables*/
proc sort data=source.QS3 nodupkey out=QS1;
by USUBJID QSTESTCD VISITNUM QSTPTNUM;
run;

data QS1;
set QS1;
ERROR="Duplicate observations for USUBJID QSTESTCD VISITNUM QSTPTNUM key variables";
run;

/*QC 2: Check for QSORRESU missing when QSSTRESU present or QSSTRESU missing when QSORRESU present.
Check for QSSTRESC missing when QSORRES present. Check for QSORRES present when QSSTRESC missing.
Check for QSSTRESN missing when QSSTRESC is present and numeric*/


data QS2 source.QS3(drop=ERROR);
length Error $100;
set source.QS3;
if QSORRES ne "" and QSSTRESC = "" then do;
Error="Alert: QSORRES present but QSSTRESC not present";
output QS2;
delete;
end;
if QSORRES = "" and QSSTRESC ne "" and QSSTRESC ne "." then do;
Error="Alert: QSSTRESC present but QSORRES not present";
output QS2;
delete;
end;
if QSSTRESN ne . and (QSSTRESC = "" or QSORRES = "") then do;
Error="Alert: QSSTRESN present but QSSTRESC or QSORRES not present.";
output QS2;
delete;
end;
if anyalpha(QSSTRESC) = 0 and findc(QSSTRESC,'!"#$%&''()+-.')= 0 and QSSTRESC ne "" and QSSTRESN = . then do;
Error="Alert: QSSTRESC present and numeric but QSSTRESN not present.";
output QS2;
delete;
end;
if QSORRESU ne "" and QSSTRESU = "" then do;
Error="Alert: QSORRESU present and numeric but QSSTRESU not present.";
output QS2;
delete;
end;
if QSSTRESU ne "" and QSORRESU = "" then do;
Error="Alert: QSSTRESU present and numeric but QSORRESU not present.";
output QS2;
delete;
end;
if QSSTRESC= "." then QSSTRESC="";
output source.QS3;
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.QS;
set EMPTY_QS source.QS3;
run;

**** SORT QS ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=QS) 

proc sort data=target.QS; 
by &QSSORTSTRING; 
run;

/*In order to utilize the macro below which uses QS1, QS2 is set to QS1 */

data source.QS1;
set source.QS2A;
run;

/*Create SuppQS Domain*/

%SUPPDOMAIN(dmname=QS)


/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.QS file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\QS.xpt" ; 
run;

proc cport data=target.SUPPQS file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPQS.xpt" ; 
run;
