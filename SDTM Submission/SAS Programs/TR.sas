/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: TR
Programmers: Vasant Raghuraman
Date: May 18, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.TR
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_TR Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TR)

/*Capturing data from supplied source dataset for VISITNUM = 0 to identify tumors at baseline
TR2 contains data for all observations*/


data source.TR1(rename=(RUSUBJID=USUBJID) DROP=LSTEST LSSEQ LSSPID LSBLFL LSCAT LSLOC LSLOC2 LSSLOC
      LSEVAL LSMETHOD LSDY RSUBJID LSTESTCD LSSTRESN) 
      source.TR2(rename=(RUSUBJID=USUBJID) DROP=LSTEST LSSEQ LSSPID LSBLFL LSCAT LSLOC LSLOC2 LSSLOC
      LSEVAL LSMETHOD LSDY RSUBJID LSTESTCD LSSTRESN)
      source.trmlsdataerror (rename=(RUSUBJID=USUBJID) DROP=LSTEST LSSEQ LSSPID LSBLFL LSCAT LSLOC LSLOC2 LSSLOC
      LSEVAL LSMETHOD LSDY RSUBJID LSTESTCD LSSTRESN);
set Original.LS;
TRORRES=LSORRES;
TRLINKID=LSSPID;
TRLOC=LSLOC;
TRLOC2=LSLOC2;
TRSLOC=LSSLOC;
TRTESTCD=put(LSTESTCD,$TRTESTCD.);
TRSTRESC=put(TRORRES,$TUMSTATE.);
TRTEST=put(LSTEST,$TRTEST.);
TREVAL=LSEVAL;
TRMETHOD=LSMETHOD;
TRDY=LSDY;
TRORRESU=put(LSORRESU,$UNIT.);
TRSTRESN=LSSTRESN;
TRSTRESU=put(TRORRESU,$UNIT.);
DOMAIN="TR";

if TRORRES="TARGET" and LSSTRESN = .  then do;
ERROR="Target lesion must have length information";
output source.trmlsdataerror;
delete;
end;
if TRMETHOD not in ('CT SCAN','MRI','MULTI-SLICE CT','SPIRAL CT SCAN','XRAY') then do;
ERROR="Method of Lesion Measurement is not from list of approved lesion measurements";
output source.trmlsdataerror;
delete;
end;
DROP LSORRES LSORRESU LSSTRESC LSSTRESU;
if LSTESTCD ne "COMBRESP" then output source.TR2;
if LSTESTCD ne "COMBRESP" and VISITNUM=0 then do;
output source.TR1;
end;
run;


/*Rename new tumors based on information collected for TU domain in source.TU4*/

proc sql;
create table source.TR2a as
select TR2.STUDYID, TR2.DOMAIN, TR2.TRLINKID, 
       (select TU4.TULINKIDnew from source.TU4 as TU4 where TR2.USUBJID=TU4.USUBJID and TR2.TRLINKID=TU4.TULINKID) as TULINKIDnew,
       TR2.TRTESTCD, TR2.TRTEST, TR2.VISITNUM, TR2.VISIT, TR2.USUBJID, TR2.TRORRES, TR2.TRORRESU,
       TR2.TRSTRESC, TR2.TRSTRESN, TR2.TRSTRESU, TR2.TREVAL, TR2.TRMETHOD, TR2.TRDY, compbl(TRLOC2||" "||TRSLOC) as TRLOCTOT       
from source.TR2 as TR2;
quit;

proc sql;
create table source.TR2B as
select TR2A.*,RFST.RFSTDT
from source.TR2A as TR2A
left join
source.RFSTDTFIN as RFST
on TR2A.USUBJID=RFST.USUBJID;
quit;


data source.TR3(drop=TULINKIDnew RFSTDT);
format STUDYID DOMAIN USUBJID TRLINKID TRTESTCD TRTEST TRORRES TRORRESU TRSTRESC TRSTRESN TRSTRESU TRMETHOD TREVAL 
       VISITNUM VISIT TRDY TRLOCTOT;
set source.TR2b;
if TULINKIDnew ne "" then TRLINKID=TULINKIDnew;
TRMETHOD=put(TRMETHOD, $METHOD.);

/* To test the proper dates we consider day 1 for all subjects as June 30, 2013 which 1s 19539*/
if TRDY ne . then do;
if TRDY>0 then TRDT=RFSTDT+TRDY-1;
if TRDY<0 then TRDT=RFSTDT+TRDY;
end;
else TRDT = .;


/*Since TRDY represents the date of measurement and not the date of Exam, TRDTC is left unpopulated*/
TRDTC="";

if substr(TRLINKID,1,3)=  "NEW" then TRLINKIDnum=3;
if substr(TRLINKID,1,2)= "NT" then TRLINKIDnum=2;
if substr(TRLINKID,1,1)= "T" then TRLINKIDnum=1;

run;

/*Get VISITNUM and VISIT information from SV domain. First combine with scheduled and remainder combine with unscheduled*/
proc sql;
create table source.TR3a as
select TR3.STUDYID, TR3.DOMAIN, TR3.USUBJID, TRLINKID, TRTESTCD, TRTEST, TRORRES, TRORRESU, TRSTRESC, TRSTRESN, TRSTRESU, TRMETHOD,
       TREVAL, SV.VISITNUM, SV.VISIT, TRDY,TRDT, TRDTC, TRLINKIDNUM, TRLOCTOT
from source.TR3 as TR3
left join
source.svcombine1 as sv
on TR3.USUBJID=SV.USUBJID and TR3.TRDT>=SV.SVSTDT and TR3.TRDT<=SV.SVENDT
order by USUBJID, VISITNUM;
quit;

data source.TR3b source.TR3d;
set source.TR3a;
if VISITNUM=. then output source.TR3b;
else output source.TR3d;
run;

proc sql;
create table source.TR3c as
select TR3b.STUDYID, TR3b.DOMAIN, TR3b.USUBJID, TRLINKID, TRTESTCD, TRTEST, TRORRES, TRORRESU, TRSTRESC, TRSTRESN, TRSTRESU, TRMETHOD,
       TREVAL, SV.VISITNUM as VISITNUM, SV.VISIT, TRDY,TRDT, TRDTC, TRLINKIDNUM, TRLOCTOT
from source.TR3b as TR3b
left join
source.SVcombine2 as SV
on TR3b.USUBJID=SV.USUBJID and TR3b.TRDT>=SV.SVSTDT and TR3b.TRDT<=SV.SVENDT and SV.SVUPDES="TR"
order by USUBJID, VISITNUM;
quit;

/*Check for the following: 
-List of lesion records where the method of measurement does not match the method used for the lesion at
baseline-Complete
-List of lesion records where the location of the lesion does not match the location listed at baseline-Complete
-List of lesion records where visit or assessment number is missing-Complete
-List of lesion records that are complete duplicates-Complete
-Gaps in visit or assessment sequences. For the purposes of this practice project- this is ignored for now.
-List of records without corresponding target/non-target lesion information at the same assessment-Complete
-Target lesions should have first visit at baseline only for changes in size to be tracked-Complete
*/

/*Delete all rows with VISITNUM and VISIT information missing*/
data source.TR3e;
set source.TR3d source.TR3c;
by USUBJID VISITNUM;
if VISITNUM ne .;
run;

/*Delete all records with duplicate lesion information*/
proc sort data=source.TR3e dupout=source.TR3f nodupkey;
by USUBJID TRLINKIDNUM TRLINKID VISITNUM;
run;

/*Get the Location information for all records*/
proc sql;
create table source.TR3g as
select TR3e.STUDYID, TR3e.DOMAIN, TR3e.USUBJID, TRLINKID, TRTESTCD, TRTEST, TRORRES, TRORRESU, TRSTRESC, TRSTRESN, TRSTRESU, TRMETHOD,
       TREVAL, VISITNUM, VISIT, TRDY,TRDT, TRDTC, TRLINKIDNUM, LOC.TULOC as TRLOC
from source.TR3e as TR3e
left join
source.Loccode as LOC
on TR3e.TRLOCTOT=LOC.TULOCTOT
order by USUBJID, TRLINKIDNUM, TRLINKID, VISITNUM;
quit;

/*Delete all records with duplicate lesion information*/
proc sort data=source.TR3g nodupkey;
by USUBJID TRLINKIDNUM TRLINKID VISITNUM;
run;

/*Get baseline Location, Method and Lesion Length information*/
data source.TR3h(keep=USUBJID TRLINKID TRLOCBL TRMETHODBL TRSTRESNBL);
set source.TR3g;
if VISITNUM=0;
TRLOCBL=TRLOC;
TRMETHODBL=TRMETHOD;
if TRTESTCD="LDIAM" then TRSTRESNBL=TRSTRESN;
run;

/*Put baseline comparison information into all rows */
proc sql;
create table source.TR3i as
select TR3g.STUDYID, TR3g.DOMAIN, TR3g.USUBJID, TR3g.TRLINKID, TRTESTCD, TRTEST, TRORRES, TRORRESU, TRSTRESC, TRSTRESN, TRSTRESU, TRMETHOD,
       TREVAL, VISITNUM, VISIT, TRDY,TRDT, TRDTC, TRLINKIDNUM, TRLOC, TRLOCBL, TRMETHODBL, TRSTRESNBL
from source.TR3g as TR3g
left join
source.TR3h as TR3h
on TR3G.USUBJID=TR3h.USUBJID and TR3g.TRLINKID=TR3h.TRLINKID
order by USUBJID, TRLINKIDNUM, TRLINKID, VISITNUM;
quit;

data source.TR3j source.TR3k;
set source.TR3i;
length ERROR $100;
if find(TRLOCBL,compbl(TRLOC), 'i') = 0 and substr(TRLINKID,1,3) ne "NEW" then do;
ERROR="The location of lesion does not match with baseline";
output source.TR3k;
delete;
end;
if TRMETHOD ne TRMETHODBL and substr(TRLINKID,1,3) ne "NEW" then do;
ERROR="The method of measurement does not match with baseline";
output source.TR3k;
delete;
end;
if TRTESTCD="LDIAM" and TRSTRESN=. then do;
ERROR="Target lesions should have first visit at baseline only for changes in size to be tracked";
output source.TR3k;
delete;
end;
if VISITNUM ne 0 and TRORRES="" then do;
ERROR="Target/Non-Target Lesion information not present";
output source.TR3k;
delete;
end;
output source.TR3j;
run;

proc sort data=source.TR3j out=source.TR5;
by USUBJID VISITNUM TRLINKIDNUM TRLINKID;
run;

data source.TR7(DROP=TRLOC TRLOCBL TRMETHODBL TRLNKGRPnum TRDT);
format STUDYID DOMAIN USUBJID TRGRPID TRLNKGRP TRLINKID TRTESTCD;
retain TRLNKGRPnum 0;
Length VISIT $40;
set source.TR5;
by USUBJID VISITNUM TRLINKIDNUM TRLINKID;
if substr(TRLINKID,1,2)= "NT" then TRGRPID="NON-TARGET";
if substr(TRLINKID,1,3)=  "NEW" then TRGRPID="NEW";
if substr(TRLINKID,1,1)= "T" then TRGRPID="TARGET";
if first.USUBJID then TRLNKGRPnum=TRLNKGRPnum+1;
TRLNKGRP=compress("A"||put(TRLNKGRPnum,4.));
run;

data source.TR8(drop=TRLINKIDnum TRSTRESNBL ERROR TRLINKID);
format STUDYID DOMAIN USUBJID TRSEQ TRGRPID TRLNKGRP TRLNKID TRTESTCD;
retain TRSEQ;
set source.TR7;
by USUBJID;
if first.USUBJID then TRSEQ=1;
else TRSEQ=TRSEQ+1;
DOMAIN="TR";
TRLNKID=TRLINKID;
run;
/*Create Empty target dataset and with attributes from metadata and populate*/

data target.TR;
set EMPTY_TR source.TR8;
run;

**** SORT TR ACCORDING TO METADATA AND SAVE PERMANENT DATASET; 

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TR) 

proc sort data=target.TR; 
by &TRSORTSTRING; 
run;


/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.TR file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\TR.xpt" ; 
run;

