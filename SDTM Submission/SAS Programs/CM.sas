/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: CM
Programmers: Vasant Raghuraman
Date: March 25, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.CM
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_CM Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=CM)

/*Capturing data from suplied source dataset. Remove numeric and special characters from CMTRT since it is not allowed as
per SDTMIG*/

data source.cm1 source.cm1a;
set Original.cm(rename=(CMDECOD=CMTRT CMATC4=CMCLAS CMATCCD=CMCLASCD RUSUBJID=USUBJID));
label CMTRT="Reported Name of Drug, Med, or Therapy";
CMTRT=compress(CMTRT,"/\","dt");
CMOCCUR=put(CMOCCUR,$NY.);
CMDOSU=put(CMDOSU,$UNIT.);
CMROUTE=put(CMROUTE,$ROUTE.);
VISIT=put(VISITNUM,VISIT.);
CMDURU=put(CMDURU,$UNIT.);
CMSTRTPT=put(CMSTRTPT,$STENRF.);
CMENRTPT=put(CMENRTPT,$STENRF.);

if anydigit(CMTRT) ne 0 and substr(CMTRT,anydigit(CMTRT)-1,1) = "/" then do;
output source.cm1a;
output source.cm1;
end;
else output source.cm1;
run;

proc sql;
create table source.cm1b as
select cm1.*,RFST.RFSTDT
from source.cm1
left join
source.RFSTDTfin as RFST
on cm1.USUBJID=RFST.USUBJID;
quit;

data source.cm1c;
set source.cm1b;
if CMSTDY>0 then CMSTDT=RFSTDT+CMSTDY-1;
else CMSTDT=RFSTDT+CMSTDT;
if CMENDY>0 then CMENDT=RFSTDT+CMENDY-1;
else CMENDT=RFSTDT+CMENDT;
if CMSTDY=. then CMSTDT=.;
run;

/*Importing raw dataset to capture Whodrug database information*/
proc import 
        datafile="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\Whodrug.csv"
        out=source.Whodrug
        dbms=csv
        replace;
		guessingrows=max;
run;

/*Joining raw dataset to WHOdrug WHO_DDE 2009 September 1 Controlled Terminology for Concommitant medication and keeping variables
only required for CM domain*/

proc sql;
create table source.cm2 as
select cm1.STUDYID, cm1.DOMAIN, cm1.USUBJID, cm1.CMSEQ, cm1.CMTRT, WHOdrug.CMDECOD label="Standardized Medication Name",
       cm1.CMCAT, cm1.CMSCAT, cm1.CMOCCUR, Whodrug.Chemical_Class as CMCLAS label="Medication Class", Whodrug.ATC_Code as CMCLASCD label="Medication Class Code",
       cm1.CMDOSE, cm1.CMDOSU, cm1.CMROUTE,  cm1.CMSTDY, cm1.CMENDY, cm1.CMDUR, cm1.CMSTRTPT, cm1.CMSTTPT, cm1.CMENRTPT,
       cm1.CMRECNO,cm1.CMSEQ1,cm1.CMSEQ2, cm1.CMSTDT, cm1.CMENDT
from source.cm1C as cm1
left join
source.Whodrug as Whodrug
on cm1.CMTRT = Whodrug.CMTRT
order by 1,2,3,4;
quit;

data source.EPOCH(keep=USUBJID SESTDT SEENDT TAETORD EPOCH);
set target.SE;
%dtc2dt(SESTDTC,prefix=SEST);
%dtc2dt(SEENDTC,prefix=SEEN);
run;


/*Get VISITNUM, VISIT from SV domain, CMSTTPT, CMENTPT as Epoch from SE domain*/
proc sql;
create table source.cm3 as
select cm2.STUDYID, cm2.DOMAIN, cm2.USUBJID, cm2.CMSEQ, cm2.CMTRT,cm2.CMDECOD,
       cm2.CMCAT, cm2.CMSCAT, cm2.CMOCCUR,cm2.CMCLAS,cm2.CMCLASCD,
       cm2.CMDOSE, cm2.CMDOSU, cm2.CMROUTE,  cm2.CMSTDY, cm2.CMENDY, cm2.CMDUR,   
cm2.CMSTRTPT, cm2.CMSTTPT as CMSTTPT1,
(select ep.SESTDT from source.EPOCH as ep where cm2.USUBJID=ep.USUBJID and ep.EPOCH="SCREENING") as SCRNDT label="Screening Date",
(select ep.EPOCH from source.EPOCH as ep where cm2.USUBJID=ep.USUBJID and cm2.CMSTDT>=ep.SESTDT and cm2.CMSTDT<=ep.SEENDT) as CMSTTPT2 label="Start Reference Time Point 2",
cm2.CMENRTPT,
(select ep.EPOCH from source.EPOCH as ep where cm2.USUBJID=ep.USUBJID and cm2.CMENDT>=ep.SESTDT and cm2.CMENDT<=ep.SEENDT) as CMENTPT label="End Reference Time Point",
cm2.CMRECNO, cm2.CMSEQ1, cm2.CMSEQ2, cm2.CMSTDT, cm2.CMENDT
from source.cm2 as cm2
order by USUBJID,CMSEQ;
quit;

data source.CM3A(drop=CMSTTPT1 CMSTTPT2 SCRNDT);
format STUDYID DOMAIN USUBJID CMSEQ CMTRT CMDECOD CMCAT CMSCAT CMOCCUR  CMCLAS CMCLASCD
       CMDOSE CMDOSU CMROUTE CMSTDY CMENDY CMDUR CMSTRTPT CMSTTPT CMENRTPT CMENTPT CMRECNO CMSEQ1 CMSEQ2 CMSTDT CMENDT;
set source.CM3;
if CMSTTPT1="V99" or CMSTTPT1="" then CMSTTPT1=CMSTTPT2;
if CMSTDT<SCRNDT and CMSTDY ne . then CMSTTPT1="SCREENING";
CMSTTPT=CMSTTPT1;
run;

/* Dummy variable CMNEWGRP will be created to group the CMTRT*/
proc sort data=source.CM3A out =source.CM3F;
by USUBJID CMDECOD CMSTTPT CMENTPT;
run;

data source.CM3G;
format USUBJID CMNEWGRP;
retain CMNEWGRP;
set source.CM3F;
by USUBJID CMDECOD CMSTTPT CMENTPT;
if first.USUBJID and first.CMDECOD then CMNEWGRP=1;
if not(first.USUBJID) and first.CMDECOD then CMNEWGRP=CMNEWGRP+1;
run;

proc sort data=source.cm3G out= source.Cm3H;
by USUBJID CMNEWGRP;
run;

/*Compact the rows to ensure One record per recorded intervention occurrence or constant-dosing interval per subject*/

data source.CM3I(drop=CMSEQ CMOCCUR CMOCCURnum CMOCCURnewnum CMDOSE CMDOSU CMSTDY CMENDY CMDUR CMSTRTPT
                        CMSTTPT CMENRTPT CMSTRTPTnum CMSTRTPTnewnum CMENRTPTnum CMENRTPTnewnum CMSTDT CMENDT 
                        CMSTTPTnum CMSTTPTnewnum CMENTPTnum CMENTPTnewnum CMSTTPT CMENTPT CMNEWGRP);
format STUDYID DOMAIN USUBJID CMSEQnew CMGRPID CMTRT CMDECOD CMCAT CMSCAT CMOCCURnew CMCLAS CMCLASCD CMDOSEnew CMDOSUnew CMROUTE
       CMSTDYnew CMENDYnew CMDURnew CMSTRTPTnew CMSTTPTnew CMENRTPTnew CMENTPTnew CMRECNO CMSEQ1 CMSEQ2;
 
set source.cm3H;

by USUBJID CMNEWGRP;

retain CMSEQnew CMOCCURnew CMOCCURnewnum CMDOSEnew CMDOSUnew CMSTDYnew CMENDYnew CMDURnew CMSTRTPTnew CMENRTPTnew 
       CMSTTPTnew CMSTTPTnewnum CMENTPTnew CMENTPTnewnum;

if first.CMNEWGRP then do;

if first.USUBJID then CMSEQnew=1; else CMSEQnew=CMSEQnew+1;

if CMOCCUR="Y" then CMOCCURnum=1;
if CMOCCUR="N" then CMOCCURNUM=2;
if CMOCCUR="" then CMOCCURNUM=3;
CMOCCURnewnum=CMOCCURnum;
CMOCCURnew=CMOCCUR;

CMDOSEnew=CMDOSE;
CMDOSUnew=CMDOSU;
CMROUTEnew=CMROUTE;
CMSTDYnew=CMSTDY;
CMENDYnew=CMENDY;
CMDURnew=input(CMDUR,8.);

if CMSTRTPT="BEFORE" then CMSTRTPTnum=1;
else CMSTRTPTnum=2;
CMSTRTPTnewnum=CMSTRTPTnum;
CMSTRTPTnew=CMSTRTPT;

if CMENRTPT="ONGOING" then CMENRTPTnum=1;
else CMENRTPTnum=2;
CMENRTPTnewnum=CMENRTPTnum;
CMENRTPTnew=CMENRTPT;

CMSTTPTnum=input(put(CMSTTPT,$TPT.),8.);
CMSTTPTnewnum=CMSTTPTnum;
CMSTTPTnew=CMSTTPT;

CMENTPTnum=input(put(CMENTPT,$TPT.),8.);
CMENTPTnewnum=CMENTPTnum;
CMENTPTnew=CMENTPT;

CMGRPID=CMNEWGRP;

end;

/*If it is not the first iteration of each group, do the following*/

if not(first.CMNEWGRP) then do;

/*Encode CMOCCUR Controlled Terminology to numeric values and get the highest level of severity start*/

if CMOCCUR="Y" then CMOCCURnum=1;
if CMOCCUR="N" then CMOCCURnum=2;
if CMOCCUR="" then CMOCCURNUM=3;

CMOCCURnewnum=min(CMOCCURnum,CMOCCURnewnum);

if CMOCCURnewnum=1 then CMOCCURnew="Y";
if CMOCCURnewnum=2 then CMOCCURnew="N";
if CMOCCURnewnum=3 then CMOCCURnew="";

/*Encode CMOCCUR Controlled Terminology to numeric values and get the highest level of severity end*/

CMDOSEnew=max(CMDOSE,CMDOSEnew);
if CMSTDY ne . then CMSTDYnew=min(CMSTDY,CMSTDYnew);
CMENDY=max(CMENDY, CMENDYnew);
CMDURnew=sum(input(CMDUR,8.),CMDURnew);

/*Encode CMSTRTPT Controlled Terminology to numeric values and get the highest level of severity start*/

if CMSTRTPT="BEFORE" then CMSTRTPTnum=1;
else CMSTRTPTnum=2;

CMSTRTPTnewnum=min(CMSTRTPTnum,CMSTRTPTnewnum);

if CMSTRTPTnewnum=1 then CMSTRTPTnew="BEFORE";
else CMSTRTPTnew="";

/*Encode CMSTRTPT Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode CMENRTPT Controlled Terminology to numeric values and get the highest level of severity Start*/

if CMENRTPT="ONGOING" then CMENRTPTnum=1;
else CMENRTPTnum=2;

CMENRTPTnewnum=min(CMENRTPTnum,CMENRTPTnewnum);

if CMENRTPTnewnum=1 then CMENRTPTnew="ONGOING";
else CMENRTPTnew="";
/*Encode CMENRTPT Controlled Terminology to numeric values and get the highest level of severity End*/



/*Encode CMSTTPT Controlled Terminology to numeric values and get the earliest Start Cycle Start*/
CMSTTPTnum=input(put(CMSTTPT,$TPT.),8.);

CMSTTPTnewnum=min(CMSTTPTnum,CMSTTPTnewnum);

CMSTTPTnew=put(CMSTTPTnewnum,TPTNUM.);
/*Encode CMSTTPT Controlled Terminology to numeric values and get the earliest Start Cycle End*/



/*Encode CMENTPT Controlled Terminology to numeric values and get the latest End Cycle Start*/
CMENTPTnum=input(put(CMENTPT,$TPT.),8.);

CMENTPTnewnum=max(CMENTPTnum,CMENTPTnewnum);

CMENTPTnew=put(CMENTPTnewnum,TPTNUM.);
/*Encode CMENTPT Controlled Terminology to numeric values and get the Latest End Cycle End*/

end;

CMGRPID=CMNEWGRP;

if last.CMNEWGRP;
run;

data source.cm4(drop=CMSEQnew CMOCCURnew CMDOSEnew CMDOSUnew CMENDYnew CMDURnew CMDURnew CMSTRTPTnew
                     CMENRTPTnew CMROUTEnew CMSEQnew CMSTDYnew CMSTTPTnew CMENTPTnew CMGRPID CMNEWGRP);
format STUDYID DOMAIN USUBJID CMSEQ CMGRPID CMTRT CMDECOD CMCAT CMSCAT CMOCCUR CMCLAS CMCLASCD CMDOSE CMDOSU CMROUTE
       CMSTDY CMENDY CMDUR CMSTRTPT CMSTTPT CMENRTPT CMENTPT CMRECNO CMSEQ1 CMSEQ2;
set source.cm3I;
CMSEQ=CMSEQnew;
CMOCCUR=CMOCCURnew;
CMDOSE=CMDOSEnew;
CMDOSU=CMDOSUnew;
CMSTDY=CMSTDYnew;
CMENDY=CMENDYnew;
CMROUTE=CMROUTEnew;
CMDUR=CMDURnew;
CMSTRTPT=CMSTRTPTnew;
CMENRTPT=CMENRTPTnew;
CMSTTPT=CMSTTPTnew;
CMENTPT=CMENTPTnew;
label CMSTTPT="Start Reference Time Point" CMENTPT="End Reference Time Point";
cmdosu=put(cmdosu,unit.);
cmroute=put(cmroute,ROUTE.); 
CMENRTPT=put(CMENRTPT,stenrf.);
CMSTRTPT=put(CMSTRTPT,stenrf.);
run;

data target.CM(drop=CMRECNO CMSEQ1 CMSEQ2);
format STUDYID DOMAIN USUBJID CMSEQ CMTRT CMDECOD CMCAT CMSCAT CMOCCUR CMCLAS CMCLASCD CMDOSE CMDOSU CMROUTE CMSTDTC CMENDTC
       CMSTDY CMENDY CMDUR CMSTRTPT CMSTTPT CMENRTPT CMENTPT;
set EMPTY_CM source.cm4;
run;

/*QC Check 1: Check for duplicate rows for key variables*/

proc sort data=target.CM nodupkey dupout=CM1 ;
by USUBJID CMDECOD CMSTTPT CMDOSU;
run;


/* The imputation of correct cycle in case of missing or issues related to compaction of rows shall be handled in Analysis Dataset*/



**** SORT CM ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=CM) 

proc sort data=target.CM; 
by &CMSORTSTRING; 
run;


data source.cm1;
set source.cm4;
run;
       
/*Create SuppCM Domain*/

%SUPPDOMAIN(dmname=CM)

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.CM file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\CM.xpt" ; 
run;

proc cport data=target.SUPPCM file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPCM.xpt" ; 
run;
