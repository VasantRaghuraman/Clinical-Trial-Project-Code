/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: TU
Programmers: Vasant Raghuraman
Date: May 18, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.TU
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_TU Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TU)

/*Capturing data from suplied source dataset for VISITNUM =0 to identify tumors at baseline in TU1
TU2 contains data for all observations*/

data source.TU1(rename=(RUSUBJID=USUBJID) DROP=LSTEST LSSEQ LSSPID LSBLFL LSCAT LSLOC LSLOC2 LSSLOC
      LSEVAL LSMETHOD LSDY RSUBJID) 
      source.TU2(rename=(RUSUBJID=USUBJID) DROP=LSTEST LSSEQ LSSPID LSBLFL LSCAT LSLOC LSLOC2 LSSLOC
      LSEVAL LSMETHOD LSDY RSUBJID)
      source.tumlsdataerror (rename=(RUSUBJID=USUBJID) DROP=LSTEST LSSEQ LSSPID LSBLFL LSCAT LSLOC LSLOC2 LSSLOC
      LSEVAL LSMETHOD LSDY RSUBJID);
set Original.LS;
TUORRES=LSCAT;
TULINKID=LSSPID;
TULOC=LSLOC;
TULOC2=LSLOC2;
TUSLOC=LSSLOC;
TUTESTCD="TUMIDENT";
TUSTRESC=put(TUORRES,$TUMIDENT.);
TUTEST="Tumor Identification";
TUEVAL=LSEVAL;
TUMETHOD=LSMETHOD;
TUDY=LSDY;
if TUORRES="TARGET" and LSSTRESN = .  then do;
ERROR="Target lesion must have length information";
output source.tumlsdataerror;
delete;
end;
if TUMETHOD not in ('CT SCAN','MRI','MULTI-SLICE CT','SPIRAL CT SCAN','XRAY') then do;
ERROR="Method of Lesion Measurement is not from list of approved lesion measurements";
output source.tumlsdataerror;
delete;
end;
DROP LSORRES LSORRESU LSSTRESC LSSTRESU;
if LSTESTCD ne "COMBRESP" then output source.TU2;
if LSTESTCD ne "COMBRESP" and VISITNUM=0 then do;
output source.TU1;
end;
run;

/*For Visitnum not equal to 0, i.e. to find new tumors after baseline,"Not Done" is not included in this baseline*/

proc sort data=source.TU1 out=source.TU1A(keep=USUBJID TULINKID) nodupkey;
by USUBJID TULINKID;
run;


proc sort data=source.TU2 out=source.TU2A(keep=USUBJID TULINKID) nodupkey;
by USUBJID TULINKID;
run;

proc sql;
create table source.TU3 as
select * from source.TU2A
except
select * from source.TU1A
order by 1,2;
quit;


data source.TU4(drop=count);
retain count;
set source.TU3;
by USUBJID;
if first.USUBJID then do;
count=1;
TULINKIDnew=compress("NEW"||count);
end;
else do;
count=count+1;
TULINKIDnew=compress("NEW"||count);
end;
run;

proc sort data=source.TU2 out=source.TU2B nodupkey;
by USUBJID TULINKID;
run;

proc sql;
create table source.TU5 as
select TU2B.STUDYID, TU2B.DOMAIN, TU2B.USUBJID, TU2B.TULINKID, TU4.TULINKID as TU4TULINKID, TU4.TULINKIDnew, TU2B.TUTESTCD, TU2B.TUTEST,
       TU2B.TUORRES, TU2B.TUSTRESC, TU2B.TUMETHOD, TU2B.TUEVAL, TU2B.VISITNUM, TU2B.VISIT, TU2B.TUDY, compbl(TULOC2||" "||TUSLOC) as TULOCTOT
from source.TU2B as TU2B
left join
source.TU4 as TU4
on TU2B.USUBJID=TU4.USUBJID and TU2B.TULINKID=TU4.TULINKID
order by USUBJID, TULINKID;
quit;

data source.TU5a(drop=TU4TULINKID TULINKIDnew);
set source.TU5;
if TULINKIDnew ne "" then TULINKID=TULINKIDnew;
run;


proc import datafile="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\Loccode.csv"
DBMS=csv
OUT=source.Loccode
REPLACE;
guessingrows=max;
run;

proc sql;
create table source.TU6 as
select STUDYID, DOMAIN, USUBJID,TULINKID, TUTESTCD, TUTEST,
       TUORRES, TUSTRESC, TUMETHOD, TUEVAL, VISITNUM, VISIT, TUDY,
	   TULOC, TULAT, TUDIR, TUPORTOT
from source.TU5a as TU5a
left join
source.Loccode as Loccode
on TU5a.TULOCTOT=Loccode.TULOCTOT;
quit;

proc sql;
create table source.TU6a as
select TU6.*,RFST.RFSTDT
from source.TU6 as TU6
left join
source.RFSTDTFIN as RFST
on TU6.USUBJID=RFST.USUBJID;
quit;


data source.TU7(drop=RFSTDT);
format STUDYID DOMAIN USUBJID TULINKID TUTESTCD TUTEST TUORRES TUSTRESC TULOC TULAT TUDIR TUPORTOT TUMETHOD TUEVAL 
       VISITNUM VISIT TUDTC TUDY;
set source.TU6a;
if TUMETHOD in ('CT SCAN','MRI','MULTI-SLICE CT','SPIRAL CT SCAN','XRAY');
TUSTRESC=put(TUSTRESC,$TUMIDENT.);
TUMETHOD=put(TUMETHOD, $METHOD.);
TUEVAL=put(TUEVAL, $EVAL.);

/* To test the proper dates we consider day 1 for all subjects as June 30, 2013 which 1s 19539*/
if TUDY ne . then do;
if TUDY>0 then TUDT=RFSTDT+TUDY-1;
if TUDY<0 then TUDT=RFSTDT+TUDY;
end;
else TUDT = .;

/*Since TUDY represents the date of measurement and not the date of Exam, TUDTC is left unpopulated*/
TUDTC="";
if substr(TULINKID,1,3)=  "NEW" then TULINKIDnum=3;
if substr(TULINKID,1,2)= "NT" then TULINKIDnum=2;
if substr(TULINKID,1,1)= "T" then do;
TULINKIDnum=1;
/*Target lesions should have first visit at baseline only for changes in size to be tracked*/
if VISITNUM ne 0 then delete;
end;
run;

proc sort data=source.TU7;
by USUBJID TULINKIDnum VISITNUM;
run;

/*Combine with SV domain to map the actual VISITNUM*/
proc sql;
create table source.TU7a as
select TU7.STUDYID, TU7.DOMAIN, TU7.USUBJID, TU7.TULINKID, TU7.TUTESTCD, TU7.TUTEST, TU7.TUORRES, TU7.TUSTRESC,
            TU7.TULOC, TU7.TULAT, TU7.TUDIR, TU7.TUPORTOT, TU7.TUMETHOD, TU7.TUEVAL, SV.VISITNUM,
            SV.VISIT, TU7.TUDTC, TU7.TUDY,TU7.TULINKIDNUM
from source.TU7 as TU7
left join
source.svcombine1 as SV
on TU7.USUBJID=SV.USUBJID and TU7.TUDT>=SV.SVSTDT and TU7.TUDT<=SV.SVENDT
order by USUBJID,TULINKIDNUM,TULINKID;
quit;



data source.TU7b(drop=TULINKIDNUM TULINKIDnew TULINKIDnum);
retain TUSEQ;
set source.TU7a;
by USUBJID TULINKIDNUM TULINKID;
if first.USUBJID then TUSEQ=1;
else TUSEQ=TUSEQ+1;
TULINKIDnew=put(TULINKID,8.);
DOMAIN="TU";
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.TU;
set EMPTY_TU source.TU7b;
run;

**** SORT TU ACCORDING TO METADATA AND SAVE PERMANENT DATASET. Not used as already sorted;
/*
%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TU) 

proc sort data=target.TU; 
by &TUSORTSTRING; 
run;*/

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.TU file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\TU.xpt" ; 
run;
