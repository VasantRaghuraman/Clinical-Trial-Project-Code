/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: CE
Programmers: Vasant Raghuraman
Date: March 20, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.CE
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_CE Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=CE)

/*Capturing data from suplied source dataset*/

data source.CE1(rename=(RUSUBJID=USUBJID));
set Original.CE;
if CETERM="" then CETERM = CELLT;
CEDICTVS="Meddra 21.1";
run;

proc sql;
create table source.CE1A as 
select CE1.*,RFST.RFSTDT
from source.CE1 as CE1
left join 
source.RFSTDTFIN as RFST
on CE1.USUBJID=RFST.USUBJID;
quit;

data source.CE1B;
set source.CE1A;
if CESTDY ne. then do;
if CESTDY>0 then CESTDT=RFSTDT+CESTDY-1;
else CESTDT=RFSTDT+CESTDY;
end;
else CESTDT=.
run;


/*Importing raw dataset to capture Meddra 21.1 database information*/
proc import 
        datafile="D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\CECT.csv"
        out=source.CECT
        dbms=csv
        replace;
		guessingrows=max;
run;

/*Map the terms for the CEDECOD and CEBODSYS from CECT controlled terminology*/
proc sql;
create table source.CE2 as 
select STUDYID, DOMAIN, USUBJID, CESEQ, CESPID, CE1.CETERM, CECAT, CEPRESP, CEOCCUR, CEMODIFY, CECT.CEDECOD, CECT.CEBODSYS, 
       CEDICTVS, CECT.CEHLGT, CECT.CEHLT, CECT.CELLT, CEORRES, CECLSIG, CESTDY, CESTDT
from source.CE1B as CE1
left join source.CECT as CECT
on CE1.CETERM=CECT.CETERM
order by 1,2,3,4;
quit;

/*Check to see if there are multiple rows with CETERM having same CESPID*/
proc sort data=source.CE2 out =source.CE2A;
by USUBJID CETERM CESPID;
run;

proc sql;
create table source.CE2B as
select USUBJID, CETERM, max(CESPID) as CESPID1 from source.CE2A
group by USUBJID, CETERM
order by 1,3,2;
quit;

proc sort data=source.CE2B nouniquekeys uniqueout=source.CE2C out=source.CE2D;
by USUBJID CESPID1;
run;

/*As there are multiple CETERM's having the same CESPID, CEGRPID is created with unique number for each CETERM */


data source.CE2E;
format USUBJID CEGRPID;
retain CEGRPID;
set source.CE2A;
by USUBJID CETERM;
if first.USUBJID and first.CETERM then CEGRPID=1;
if not(first.USUBJID) and first.CETERM then CEGRPID=CEGRPID+1;
run;

data source.CE2F(drop=CESEQ CEPRESP CEPRESPnum CEOCCUR CEOCCURnum CEMODIFY CEDICTVS CESTDT CEORRESnum CEORRESnewnum CEORRES
                      CESTDY CESPID CECLSIG CECLSIGnum CEPRESPnewnum CEOCCURnewnum CECLSIGnewnum);

format STUDYID DOMAIN USUBJID CESEQnew CEGRPID CETERM CEDECOD CECAT CEPRESPnew  CEOCCURnew 
       CEBODSYS CESTDYnew CESTDTnew CEORRESnew CECLSIGnew ;
       
set source.CE2E;

by USUBJID CEGRPID;

retain CESEQnew CEPRESPnew CEPRESPnewnum CEOCCURnew CEOCCURnewnum CESTDYnew CESTDTnew CEORRESnew CEORRESnewnum;

/*During the first iteration for each group, do the following*/

if first.CEGRPID then do;

if first.USUBJID then CESEQnew=1; else CESEQnew=CESEQnew+1;

if CEPRESP="Y" then CEPRESPnum=1;
else CEPRESPnum=2;
CEPRESPnewnum=CEPRESPnum;
CEPRESPnew=CEPRESP;

if CEOCCUR="Y" then CEOCCURnum=1;
else CEOCCURnum=2;
CEOCCURnewnum=CEOCCURnum;
CEOCCURnew=CEOCCUR;

if CECLSIG="Y" then CECLSIGnum=1;
else CECLSIGnum=2;
CECLSIGnewnum=CECLSIGnum;
CECLSIGnew=CECLSIG;


if CEORRES="ABNORMAL" then CEORRESnum=1;
if CEORRES="NORMAL" then CEORRESnum=2;
if CEORRES="NOT APPLICABLE" then CEORRESnum=3;
if CEORRES="" then CEORRESnum=4;
CEORRESnewnum=CEORRESnum;
CEORRESnew=CEORRES;

CESTDYnew=CESTDY;
CESTDTnew=CESTDT;

end;

/*If it is not the first iteration of each group, do the following*/

if not(first.CEGRPID) then do;

/*Encode CEGRPID Controlled Terminology to numeric values and get the highest level of severity start*/

if CEPRESP="Y" then CEPRESPnum=1;
else CEPRESPnum=2;

CEPRESPnewnum=min(CEPRESPnum,CEPRESPnewnum);

if CEPRESPnewnum=1 then CEPRESPnew="Y";
else CEPRESPnew="";

/*Encode CEGRPID Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode CEOCCUR Controlled Terminology to numeric values and get the highest level of severity start*/
if CEOCCUR="Y" then CEOCCURnum=1;
else CEOCCURnum=2;

CEOCCURnewnum=min(CEOCCURnum,CEOCCURnewnum);

if CEOCCURnewnum=1 then CEOCCURnew="Y";
else CEOCCURnew="";

/*Encode CEOCCUR Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode CECLSIG Controlled Terminology to numeric values and get the highest level of severity start*/

if CECLSIG="Y" then CECLSIGnum=1;
else CECLSIGnum=2;

CECLSIGnewnum=min(CECLSIGnum,CECLSIGnewnum);

if CECLSIGnewnum=1 then CECLSIGnew="Y";
else CECLSIGnew="";

/*Encode CECLSIG Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode CEORRES Controlled Terminology to numeric values and get the highest level of severity start*/

if CEORRES="ABNORMAL" then CEORRESnum=1;
if CEORRES="NORMAL" then CEORRESnum=2;
if CEORRES="NOT APPLICABLE" then CEORRESnum=3;
if CEORRES="" then CEORRESnum=4;

CEORRESnewnum=min(CEORRESnum,CEORRESnewnum);

if CEORRESnewnum=1 then CEORRESnew="ABNORMAL";
if CEORRESnewnum=2 then CEORRESnew="NORMAL";
if CEORRESnewnum=3 then CEORRESnew="NOT APPLICABLE";
if CEORRESnewnum=4 then CEORRESnew="";


/*Encode CEORRES Controlled Terminology to numeric values and get the highest level of severity end*/


CESTDYnew=min(CESTDY,CESTDYnew);
CESTDTnew=min(CESTDT,CESTDTnew);

end;
if last.CEGRPID;
run;

data source.CE2G(DROP=CEPRESPnew CEOCCURnew CESTDYnew CECLSIGnew CEHLGT CEHLT CELLT CEGRPID CESEQnew CESTDTnew CEORRESnew);
format STUDYID DOMAIN USUBJID CESEQ CETERM CEDECOD CECAT CEPRESP CEOCCUR CEBODSYS CEDTC CEDY ;
length CEDTC $16;
set source.CE2F;
CEPRESP=CEPRESPnew;
CEOCCUR=CEOCCURnew;
CEDY=CESTDYnew;
if CESTDTnew = . then CEDTC=""; 
else CEDTC=put(CESTDTnew,is8601da.);
CECLSIG=CECLSIGnew;
CESEQ=CESEQnew;
CEORRES=CEORRESnew;
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.CE(drop=CECLSIG CEENTPT CEORRES);
set EMPTY_CE source.CE2G;
run;

**** SORT CE ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=CE) 

proc sort data=target.CE; 
by &CESORTSTRING; 
run;

/*Transfer SUPPCE variables to Excel file to input metadata*/
PROC EXPORT DATA= SOURCE.CE8 
            OUTFILE= "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\CE8.csv" 
            DBMS=CSV LABEL REPLACE;
     PUTNAMES=YES;
RUN;

/*In order to utilize the macro below which uses CE1, CE2 is set to CE1 */

data source.ce1;
set source.ce2G;
label CECLSIG="Clinically Significant" CEORRES="Outcome Of Clinical Event";
run;

/*Create SuppCE Domain*/

%SUPPDOMAIN(dmname=CE)

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.CE file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\CE.xpt" ; 
run;

proc cport data=target.SUPPCE file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPCE.xpt" ; 
run;
