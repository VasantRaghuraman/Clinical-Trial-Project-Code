%Macro SUPPDOMAIN(dmname=); 
%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=SUPP)

PROC IMPORT OUT= SOURCE.SUPPVARS 
            DATAFILE= "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\SUPPvars.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
 guessingrows=max;
RUN;

data source.suppvars1;
set source.suppvars;
if Domain= "&dmname.";
run;

proc sql noprint;
select Variable into :suppvarnm separated by ' '
from source.suppvars1;
quit;

data _null;
%put &suppvarnm;
run;

data source.supp&dmname.1;
set source.&dmname.1;
run;

data source.supp&dmname.2(keep= USUBJID STUDYID RDOMAIN IDVAR IDVARVAL &suppvarnm);
format USUBJID RDOMAIN  STUDYID IDVAR IDVARVAL &suppvarnm;

set source.&dmname.1;

IDVAR="&dmname.SEQ";
IDVARVAL=put(&dmname.SEQ,3.);
RDOMAIN=DOMAIN;

run;

proc sort data=source.supp&dmname.2;
by STUDYID RDOMAIN USUBJID IDVAR IDVARVAL;
run;


proc transpose data=source.supp&dmname.2 out=source.supp&dmname.3
	name=QNAM
	prefix=QVAL;
	by STUDYID RDOMAIN USUBJID IDVAR IDVARVAL;
	var &suppvarnm.;
run;


data source.supp&dmname.4(drop=_LABEL_ QVAL1);
set source.supp&dmname.3;
QLABEL=_LABEL_;
QVAL=QVAL1;
label QNAM="Qualifier Variable Name" QLABEL="Qualifier Variable Label" QVAL="Data Value";
run;



proc sql;
create table source.supp&dmname.5 as
select supp.STUDYID, supp.RDOMAIN, supp.USUBJID, supp.IDVAR, supp.IDVARVAL, supp.QNAM, 
       supp.QLABEL, supp.QVAL, meta.QORIG as QORIG label="Origin", meta.QEVAL as QEVAL label="Evaluator"
from source.supp&dmname.4 as supp 
left join
source.suppvars as meta
on supp.QNAM=meta.variable and supp.RDOMAIN=meta.domain
order by 1,2,3,4,5,6;
quit;


/* Create Empty target dataset and with attributes from metadata and populate*/
proc sql;
create table target.SUPP&dmname. like Empty_SUPP;
quit;

data target.SUPP&dmname.;
set target.SUPP&dmname. source.supp&dmname.5;
run;


proc sort data=target.SUPP&dmname.; 
by STUDYID RDOMAIN USUBJID IDVAR IDVARVAL QNAM; 
run;


%mend SUPPDOMAIN;






