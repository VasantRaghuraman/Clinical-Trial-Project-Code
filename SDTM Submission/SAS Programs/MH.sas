%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_MH Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=MH)

/*Capturing data from suplied source dataset*/

data source.mh1;
set Original.mh(rename=(RUSUBJID=USUBJID));
MHTERM=MHLLT;
label MHTERM="Reported Term for the Medical History";
mhdictvs="Meddra 21.1";
run;

/*Importing raw dataset to capture Meddra database information*/
proc import 
        datafile="D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\MHLT2.csv"
        out=source.mhmeddra
        dbms=csv
        replace;
		guessingrows=max;
run;

/*Joining raw dataset to Meddra 21.1 Controlled Terminology for Medical History information and keeping variables
only required for MH domain*/

proc sql;
create table source.mh3 as
select mh1.STUDYID, mh1.DOMAIN, mh1.USUBJID, mh1.MHSEQ, mh1.MHSPID, mh1.MHTERM label="Reported Term for the Medical History",
       mhmed.Preferred_Term as MHDECOD label="Dictionary-Derived Term", mh1.MHCAT, mh1.MHPRESP, mh1.MHOCCUR, 
       mhmed.Body_System_Or_Organ_Class as MHBODSYS label="Body System or Organ Class", 
       mh1.MHSTDY, mh1.MHENRTPT, mh1.VISIT as MHENTPT label="End Reference Time Point",
	   mhmed.Lowest_Level_Term as MHLLT label="Lowest Level Term", mhmed.High_Level_Term as MHHLT label="High Level Term",
	   mhmed.High_Level_Group_Term as MHHLGT label="High Level Group Term", mh1.mhcontr, mh1.mhdictvs, mh1.visitnum 
from source.mh1 as mh1
left join
source.mhMeddra as mhmed
on mh1.MHTERM = mhmed.MHTERM
order by 1,2,3,4;
quit;

proc sql;
create table source.mh3a as
select mh3.*,RFSTDT
from source.mh3 as mh3
left join
source.RFSTDTFIN as RFST
on mh3.USUBJID=RFST.USUBJID;
quit;

data source.mh4(drop = MHSTDY MHLLT MHHLT MHHLGT MHSTDT VISITNUM RFSTDT);
format STUDYID DOMAIN USUBJID MHSEQ MHSPID MHTERM MHDECOD MHCAT MHPRESP MHOCCUR MHBODSYS MHSTDTC MHENRTPT MHENTPT;
set source.mh3a;

if MHSTDY ne . then do;
if MHSTDY>0 then MHSTDT=RFSTDT+MHSTDY-1;
if MHSTDY<0 then MHSTDT=RFSTDT+MHSTDY;
end;
else MHSTDT = .;

if MHSTDT ne . then MHSTDTC=put(MHSTDT,IS8601da.);
else MHSTDTC="";

run;

/*No need to Map VISITNUM and VISIT values from SV domain*/




/*Create Empty target dataset and with attributes from metadata and populate*/



data target.MH;
set Empty_MH source.mh4;
run;

**** SORT MH ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=MH) 

proc sort data=target.MH; 
by &MHSORTSTRING; 
run;

/*Find out which variables are required for the SUPPMH dataset*/

proc transpose data = target.MH(obs=0) out=source.MH5;
var _all_;
run;

proc sql noprint;
 select _name_ into : list separated by ' '
  from source.mh5;
quit;

data _null_;
%put &list;
run;

/*Get the variables from source.MH1 to MH6*/
proc transpose data = source.MH1(obs=0) out=source.MH6;
var _all_;
run;

proc sql noprint;
 select _name_ into : list separated by ' '
  from source.MH6;
quit;

data _null_;
%put &list;
run;

/*Compare all the variables of CM according to variables in MH6 to MH5 to see which variables need to be removed to create SUPPMH dataset*/

proc sql;
create table source.MH7 as
select _NAME_ from source.MH6
except 
select _NAME_ from source.MH5;
quit;

proc sql noprint;
 select _NAME_ into : list separated by ' '
  from source.MH7;
quit;

data _null_;
%put &list;
run;


/*Transfer SUPPMH variables to Excel file to input metadata*/
PROC EXPORT DATA= SOURCE.MH7 
            OUTFILE= "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\MH7.csv" 
            DBMS=CSV LABEL REPLACE;
     PUTNAMES=YES;
RUN;

/*In order to ebsure that the SUPPMH domain contains the new meddra 21.1 terms, source.mh1 is modified to reflect it*/

data source.mh1;
set source.mh3;
run;


/*Create SuppMH Domain*/

%SUPPDOMAIN(dmname=MH)

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.MH file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\MH.xpt" ; 
run;

proc cport data=target.SUPPMH file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPMH.xpt" ; 
run;
