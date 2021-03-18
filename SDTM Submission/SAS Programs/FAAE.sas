/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: FAAE
Programmers: Vasant Raghuraman
Date: March 13, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.AE
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_AE Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=FAAE)

/* To test the proper dates we consider day 1 for all subjects as June 30, 2013 which 1s 19539*/

data _null_;
var=put(19539,date9.);
put "The date 19539 is:" var;
run;

proc sql;
create table source.aerf as
select ae.*, RFST.RFSTDT
from original.ae as ae
left join
source.RFSTDTFIN as RFST
on ae.RUSUBJID=RFST.USUBJID;
quit;

/*Capturing data from suplied source dataset*/

data source.FAAE1(Drop= AEREFID AEBODSYS AESER AEREL AESOD AECONTRT AESCONG AESDISAB AESLIFE AESTDY AEDICTVS AESTDYNEW
                  AEHLGT AEHLT AEORDER AEPREG AETRTEM AESERDY AESTWK AESERWK AEDECOD AEENDY RSUBJID AESMIE AEDYNEW AEENDY RFSTDT);
format STUDYID DOMAIN USUBJID AESPID;
set source.aerf(rename=(RUSUBJID=USUBJID));
AEDICTVS="Meddra21.1";
AETERM=AELLT;
if AEREFID ne "" then AESPID=AEREFID;

if AESTDY =. and AESERDY=. then AEDYNEW=.;
else AEDYNEW=max(AESTDY,AESERDY);

if AEDYNEW ne . then do;
if AEDYNEW>0 then AESTUDYDT=RFSTDT+AEDYNEW-1;
if AEDYNEW<0 then AESTUDYDT=RFSTDT+AEDYNEW;
end;
else AESTUDYDT = .;
format AESTUDYDT date9.;

if AEENDY ne . then do;
if AEENDY>0 then AEENDSTUDYDT=RFSTDT+AEENDY-1;
if AEENDY<0 then AEENDSTUDYDT=RFSTDT+AEENDY;
end;
else AEENDSTUDYDT = .;
format AEENDSTUDYDT date9.;

if AEDTHWK =. and AESERWK=. and AESTWK=. then AESTDYNEW=.;
else AESTDYNEW=max(AEDTHWK*7, AESTWK*7, AESTDYNEW*7);

if AESTDYNEW ne . then do;
if AESTDYNEW>0 then AESTDT=RFSTDT+AESTDYNEW-1;
if AESTDYNEW<0 then AESTDT=RFSTDT+AESTDYNEW;
end;
else AESTDT = .;
format AESTDT date9.;

if AESTDT ne . then AESTDTC=put(AESTDT,IS8601da.);
else AESTDTC="";

run;

proc sort data=source.svcombine out=source.svcombine3 nodupkey;
by USUBJID SVSTDT;
run;



/* Since there are no Unscheduled observations i.e. VISITNUM=99, they do not need to be separated
For the visits where there are AESTDT, use them to create VISITNUM. Otherwise use VISITNUM from collected*/

proc sql;
create table source.FAAE2a as
select FAAE1.STUDYID, FAAE1.DOMAIN, FAAE1.USUBJID, FAAE1.AESPID, FAAE1.AEACN, FAAE1.AEPATT, FAAE1.AEOUT, FAAE1.AESDTH,
       FAAE1.AESHOSP, FAAE1.AETOXGR,FAAE1.AESEQ,
       FAAE1.VISITNUM, FAAE1.VISIT, FAAE1.AEDUR, FAAE1.AEACCOL, FAAE1.AEDURU,
       FAAE1.AELLT,FAAE1.AEOUTCOL,FAAE1.AETERM, FAAE1.AESTUDYDT, FAAE1.AEENDSTUDYDT, 
       FAAE1.AESTDT, FAAE1.AESTDTC, 
       SV.VISITNUM as VISITNUMNEW label="New VISITNUM", SV.VISIT as VISITNEW label="NEW VISIT"
from source.FAAE1 as FAAE1 
left join
source.svcombine3 as SV
on FAAE1.USUBJID=SV.USUBJID and SV.VISITNUM<92 and FAAE1.AESTDT>=sv.SVSTDT and FAAE1.AESTDT<=sv.SVENDT
order by USUBJID,AESEQ;
quit;


proc sql;
create table source.FAAE2b as
select FAAE2a.STUDYID, FAAE2a.DOMAIN, FAAE2a.USUBJID, FAAE2a.AESPID, FAAE2a.AEACN, FAAE2a.AEPATT, FAAE2a.AEOUT, FAAE2a.AESDTH,
       FAAE2a.AESHOSP, FAAE2a.AETOXGR,FAAE2a.AESEQ,
       FAAE2a.VISITNUM, FAAE2a.VISIT, FAAE2a.AEDUR, FAAE2a.AEACCOL, FAAE2a.AEDURU,
       FAAE2a.AELLT,FAAE2a.AEOUTCOL,FAAE2a.AETERM, FAAE2a.AESTUDYDT, FAAE2a.AEENDSTUDYDT, 
       FAAE2a.AESTDT, FAAE2a.AESTDTC, FAAE2a.VISITNUMNEW,FAAE2a.VISITNEW label="NEW VISIT",
	   SV.VISITNUM as VISITNUMSTDY label="New Study VISITNUM", SV.VISIT as VISITSTUDYNEW label="NEW Study VISIT"
from source.FAAE2a as FAAE2a 
left join
source.svcombine3 as SV
on FAAE2a.USUBJID=SV.USUBJID and SV.VISITNUM<92 and FAAE2a.AESTUDYDT>=sv.SVSTDT and FAAE2a.AESTUDYDT<=sv.SVENDT
order by USUBJID,AESEQ;
quit;


/*Remove duplicate observations caused by unscheduled visits matching scheduled visits*/
proc sort data=source.FAAE2b;
by USUBJID AESEQ VISITNUMNEW VISITNUMSTDY;
run;

proc sort data=source.FAAE2b dupout=source.FAAE2C nodupkey;
by USUBJID AESEQ;
run;

/* In this case, since study day start date contains wrong dates, cycle information is used.
ordinarily these dates would be sent to data management team. FADTC is not provided in this case*/
data source.FAAE2d(drop=VISITNUMNEW VISITNEW VISITNUMSTDY VISITSTUDYNEW);
set source.FAAE2B;
if VISITNUM ne . then do;
VISIT=put(VISITNUM,VISIT.);
end;
else do;
     if VISITNUMnew ne . then do;
	    VISITNUM=VISITNUMNEW;
        VISIT=put(VISITNUM,VISIT.);
	 end;
	 else do;
	 		if VISITNUMSTDY ne . then do;
 			   VISITNUM=VISITNUMNEW;
               VISIT=put(VISITNUM,VISIT.);
	        end;
	 end;
end;
run;


proc sort data=source.FAAE2D out=source.FAAE2E;
by USUBJID AELLT AEPATT VISITNUM;
run;


data source.FAAE2F(drop=AESTUDYDT AEENDSTUDYDT AESTDT AESTDTC AESEQ);
format USUBJID AELLT AEPATT FAGRPID VISITNUM VISIT;
retain FAGRPID;
set source.FAAE2E;
by USUBJID AELLT AEPATT VISITNUM;
if first.USUBJID and AEPATT="NEW" then FAGRPID=1;
if not(first.USUBJID) and AEPATT="NEW" then FAGRPID=FAGRPID+1;
run;


data source.FAAE3a(DROP=AETERM AESPID AEACCOL AELLT AEOUTCOL AEPATT AESDTH AESHOSP AETOXGR AEDUR AEDURU AEACN AEOUT);
format STUDYID DOMAIN USUBJID FAGRPID FASPID FAOBJ VISITNUM VISIT FATESTCD FATEST FAORRES FAORRESU FASTRESC FASTRESN FASTRESU;
set source.FAAE2F;
FASPID=AESPID;
FAOBJ=AETERM;
FATESTCD="AEACN";
FATEST="Action Taken with Study Treatment";
format FATESTCD FATESTCD. FATEST FATEST.;
FAORRES=AEACCOL;
FASTRESC=AEACN;
FAORRESU="";
FASTRESN=.;
FASTRESU="";
run;


data source.FAAE3b(DROP=AETERM AESPID AEACCOL AEOUTCOL AEPATT AESDTH AESHOSP AETOXGR AEDUR AEDURU AEACN AELLT AEOUT);
format STUDYID DOMAIN USUBJID FAGRPID FASPID FAOBJ VISITNUM VISIT FATESTCD FATEST FAORRES FAORRESU FASTRESC FASTRESN FASTRESU;
set source.FAAE2F;
FASPID=AESPID;
FAOBJ=AETERM;
FATESTCD="AEOUT";
FATEST="Outcome of Adverse Event";
format FATESTCD FATESTCD. FATEST FATEST.;
FAORRES=AEOUTCOL;
FASTRESC=AEOUT;
FAORRESU="";
FASTRESN=.;
FASTRESU="";
run;


data source.FAAE3c(DROP=AETERM AESPID AEACCOL AEOUTCOL AEPATT AESDTH AESHOSP AETOXGR AEDUR AEDURU AEACN AELLT AEOUT);
format STUDYID DOMAIN USUBJID FAGRPID FASPID FAOBJ VISITNUM VISIT FATESTCD FATEST FAORRES FAORRESU FASTRESC FASTRESN FASTRESU;
set source.FAAE2F;
FASPID=AESPID;
FAOBJ=AETERM;
FATESTCD="AEPATT";
FATEST="Pattern of Adverse Event";
format FATESTCD FATESTCD. FATEST FATEST.;
FAORRES=AEPATT;
FASTRESC=AEPATT;
FAORRESU="";
FASTRESN=.;
FASTRESU="";
run;


data source.FAAE3d(DROP=AETERM AESPID AEACCOL AEOUTCOL AEPATT AESDTH AESHOSP AETOXGR AEDUR AEDURU AEACN AELLT AEOUT);
format STUDYID DOMAIN USUBJID FAGRPID FASPID FAOBJ VISITNUM VISIT FATESTCD FATEST FAORRES FAORRESU FASTRESC FASTRESN FASTRESU;
set source.FAAE2F;
FASPID=AESPID;
FAOBJ=AETERM;
FATESTCD="AESHOSP";
FATEST="Requires or Prolongs Hospitalization";
format FATESTCD FATESTCD. FATEST FATEST.;
FAORRES=AESHOSP;
FASTRESC=AESHOSP;
FAORRESU="";
FASTRESN=.;
FASTRESU="";
run;


data source.FAAE3e(DROP=AETERM AESPID AEACCOL AEOUTCOL AEPATT AESDTH AESHOSP AETOXGR AEDUR AEDURU AEACN AELLT AEOUT);
format STUDYID DOMAIN USUBJID FAGRPID FASPID FAOBJ VISITNUM VISIT FATESTCD FATEST FAORRES FAORRESU FASTRESC FASTRESN FASTRESU;
set source.FAAE2F;
FASPID=AESPID;
FAOBJ=AETERM;
FATESTCD="AETOXGR";
FATEST="Standard Toxicity Grade";
format FATESTCD FATESTCD. FATEST FATEST.;
FAORRES=AETOXGR;
FASTRESC=AETOXGR;
FAORRESU="";
FASTRESN=.;
FASTRESU="";
run;


data source.FAAE3f(DROP=AETERM AESPID AEACCOL AEOUTCOL AEPATT AESDTH AESHOSP AETOXGR AEDUR AEDURU AEACN AELLT AEOUT);
format STUDYID DOMAIN USUBJID FAGRPID FASPID FAOBJ VISITNUM VISIT FATESTCD FATEST FAORRES FAORRESU FASTRESC FASTRESN FASTRESU;
set source.FAAE2F;
FASPID=AESPID;
FAOBJ=AETERM;
FATESTCD="AEDUR";
FATEST="Duration of Adverse Event";
format FATESTCD FATESTCD. FATEST FATEST.;
FAORRES=put(AEDUR,8.);
FASTRESC=put(AEDUR,8.);
FAORRESU=AEDURU;
FASTRESN=input(AEDUR,8.);
FASTRESU=AEDURU;
format FASTRESU UNIT.;
run;

data source.faae4;
length FATESTCD $8 FATEST $40 FAORRESU $20 FASTRESU $20;
format STUDYID DOMAIN USUBJID FAGRPID FASPID FAOBJ VISITNUM VISIT FATESTCD FATEST FAORRES FAORRESU FASTRESC FASTRESN FASTRESU;
set source.FAAE3a source.FAAE3b source.FAAE3c source.FAAE3d source.FAAE3e source.FAAE3f;
run;

proc sort data=source.FAAE4;
by USUBJID FAGRPID FATESTCD FAOBJ VISITNUM;
run;

data source.FAAE5(drop=FAGRPID);
format STUDYID DOMAIN USUBJID FAGRPID1 FASEQ FASPID FAOBJ VISITNUM VISIT FATESTCD FATEST FAORRES FAORRESU FASTRESC FASTRESN FASTRESU;
retain FASEQ;
set source.FAAE4;
by USUBJID FAGRPID FATESTCD FAOBJ VISITNUM;
DOMAIN="FA";
if first.USUBJID then FASEQ=1; else FASEQ=FASEQ+1;
FAGRPID1=put(FAGRPID,5.);
run;

data target.FAAE(drop=FAGRPID1);
format STUDYID DOMAIN USUBJID FAGRPID FASEQ FASPID FAOBJ VISITNUM VISIT FATESTCD FATEST FAORRES FAORRESU FASTRESC FASTRESN 
       FASTRESU;
set EMPTY_FAAE source.FAAE5;
FAGRPID=FAGRPID1;
run;


**** SORT FAAE ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=FAAE) 

proc sort data=target.FAAE; 
by &FAAESORTSTRING; 
run;


/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.FAAE file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\FAAE.xpt" ; 
run;