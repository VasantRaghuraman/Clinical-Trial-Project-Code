/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: EC
Programmers: Vasant Raghuraman
Date: April 11, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.EC
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_DS Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=EC)

/*Capturing data from suplied source dataset. ECTERM is assumed to be ECDECOD as it was redacted*/

data source.EC1(rename=(RUSUBJID=USUBJID) drop=RSUBJID EXSPID);
format STUDYID DOMAIN;
set Original.EX;
run;

/*Since Original.EX visits are based on protocol requirements and there are no unplanned visits, 
         the original VISIT is retained as EPOCH*/

data source.EC2(drop=EXSEQ EXTRT EXDOSE EXDOSU EXDOSFRM EXDUR EXTPT EXLEVD EXOCCUR EXSTTM EXENTM EXPDOSU EXPDOSE 
                EXSET EXDOMIFL EXDREDFL EXDELFL  EXTPTNUM ECSTDTM ECENDTM RFSTDT ECSTTM ECENTM);
/*format STUDYID DOMAIN USUBJID ECSEQ ECTRT ECOCCUR ECDOSE  ECDOSU ECDOSFRM EPOCH ECSTDTC ECENDTC ECSTDY ECENDY  
       ECTPT ECTPTNUM ;*/
set source.EC1A;
ECSEQ=EXSEQ;
ECTRT=EXTRT;
ECDOSE=EXDOSE;
ECDOSU=put(EXDOSU,$UNIT.);
ECDOSFRM=put(EXDOSFRM,$FRM.);
EPOCH=put(VISIT,$EPOCH.);
ECDUR=EXDUR;
ECTPT=EXTPT;
ECTPTNUM=EXTPTNUM;
ECLEVD=EXLEVD;
ECOCCUR=EXOCCUR; 
ECSTDY=EXSTDY;
ECENDY=EXENDY;
ECPDOSU=put(EXPDOSU,$UNIT.);
ECPDOSE=EXPDOSE;
ECLEVD=EXLEVD;
ECSET=EXSET;
ECDOMIFL=EXDOMIFL;
ECDREDFL=EXDREDFL;
ECDELFL=EXDELFL;
ECSTTM=EXSTTM;
ECENTM=EXENTM;

/* EXSTDY is labelled as Start Day of Treatment and EXENDY is labelled as END Day Of Treatment
Hence ECSTDTC and ECENDTC are calculated Here 19539 is selected as base date as it is not available.
From first  dare of dosing, RFSTDTC is derived*/

if ECSTDY ne . then do;
if ECSTDY>0 then ECSTDT=19539+ECSTDY-1;;
if ECSTDY<0 then ECSTDT=19539+ECSTDY;
end;
else ECSTDT = .;

if _n_=1 then put RFSTDT 8.;

if ECENDY ne . then do;
if ECENDY>0 then ECENDT=19539+ECENDY-1;
if ECENDY<0 then ECENDT=19539+ECENDY;
end;
else ECENDT = .;

if ECSTDT ne . then do;
	if EXSTTM ne . then do;
			ECSTDTM=dhms(ECSTDT,0,0,EXSTTM); 
			ECSTDTC=put(ECSTDTM,IS8601dt.);
	end;
	else ECSTDTC=put(ECSTDT,IS8601da.);
end;
else ECSTDTC="";


if ECENDT ne . then do;
	if EXENTM ne . then do;
			ECENDTM=dhms(ECENDT,0,0,EXENTM); 
			ECENDTC=put(ECENDTM,IS8601dt.);
	end;
	else ECENDTC=put(ECENDT,IS8601da.);
end;
else ECENDTC="";


label ECLEVD="Dose Level" ECSET="Investigational Product Admin. Setting" ECDOMIFL="Dose Omitted Flag" ECPDOSE="Planned Dose Per Administration"
      ECDREDFL="Dose Reduced Flag" ECDELFL="Dose Delayed Flag" ECSTTM="Start Time of Treatment" ECENTM="End Time of Treatment"
	  ECPDOSU="Planned Dose Units per Administration";
run;

data source.EC3(drop=ECLEVD ECSET ECDOMIFL ECDREDFL ECDELFL ECSTTM ECENTM VISIT ECOCCUR  ECPDOSE ECPDOSU VISITNUM ECSTDT ECENDT
                      EXSTDY EXENDY);
set source.EC2;
DOMAIN="EC";
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.EC;
set Empty_EC source.EC3;
run;

**** SORT EC ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=EC) 

proc sort data=target.EC; 
by &ECSORTSTRING; 
run;


/*Find out which variables are required for the SUPPEC dataset*/

proc transpose data = source.EX3(obs=0) out=source.EC6;
var _all_;
run;

proc sql noprint;
 select _name_ into : list separated by ' '
  from source.EC6;
quit;

data _null_;
%put &list;
run;

/*Get the variables from source.EC2 to EC7*/
proc transpose data = source.EC2(obs=0) out=source.EC7;
var _all_;
run;

proc sql noprint;
 select _name_ into : list separated by ' '
  from source.EC7;
quit;

data _null_;
%put &list;
run;

/*Compare all the variables of EX according to variables in EX6 to EX7 to see which variables need to be removed to create SUPPEX dataset*/

proc sql;
create table source.EC8 as
select _NAME_ from source.EC7
except 
select _NAME_ from source.EC6;
quit;

proc sql noprint;
 select _NAME_ into : list separated by ' '
  from source.EC8;
quit;

data _null_;
%put &list;
run;


/*Transfer SUPPEC variables to Excel file to input metadata*/
PROC EXPORT DATA= SOURCE.EC8 
            OUTFILE= "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\EC8.csv" 
            DBMS=CSV LABEL REPLACE;
     PUTNAMES=YES;
RUN;

/*Create SuppEC Domain. Get the variables into EC1 domain for the macro*/
data source.EC1;
set source.EC2;
run;

%SUPPDOMAIN(dmname=EC)

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.EC file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\EC.xpt" ; 
run;

proc cport data=target.SUPPEC file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPEC.xpt" ; 
run;
