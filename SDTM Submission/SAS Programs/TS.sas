%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TS)

/* Inserting values into target.TS dataset based on the Trial Design Matrix and supplied values in source.ts dataset*/
 
data SOURCE.TS    ;
%let _EFIERR_ = 0; /* set the ERROR detection macro variable */
infile 'D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\ts.csv' delimiter = ',' MISSOVER DSD lrecl=32767 firstobs=2 ;
	informat STUDYID $8. ;
	informat DOMAIN $2. ;
	informat TSSEQ best32. ;
	informat TSGRPID $5. ;
	informat TSPARMCD $8. ;
	informat TSPARM $42. ;
	informat TSVAL $610. ;
	informat TSVALNF $4. ;
	informat TSVALCD $10. ;
	informat TSVCDREF $9. ;
	informat TSVCDVER $10. ;
	informat Required $1. ;
	format STUDYID $8. ;
	format DOMAIN $2. ;
	format TSSEQ best12. ;
	format TSGRPID $5. ;
	format TSPARMCD $8. ;
	format TSPARM $42. ;
	format TSVAL $610. ;
	format TSVALNF $4. ;
	format TSVALCD $10. ;
	format TSVCDREF $9. ;
	format TSVCDVER $10. ;
	format Required $1. ;

input STUDYID$ DOMAIN$  TSSEQ  TSGRPID$  TSPARMCD$ TSPARM$ TSVAL$  TSVALNF$ TSVALCD$ TSVCDREF$ TSVCDVER Required$;
if _ERROR_ then call symputx('_EFIERR_',1);  /* set ERROR detection macro variable */
run;


data source.ts1(drop = Required);
set source.ts;
If upcase(Required) = "Y";
run;

/*Invoke macro to convert TSVAL greater than 200 characters to TSVAL, TSVAL1...TSVALn*/ 

%AddVar(in_data=source.ts1 , in_var=TSVAL , splitchar=~ , maxlen=200 , out_data=source.ts2 , out_pre=TSVAL)

/*Order the variables TSVAL, TSVAL1...TSVALn*/
proc transpose data = source.ts2(obs=0) out=source.ts3;
var _all_;
run;

data source.ts6;
set source.ts3;

  IF find(_name_,"STUDYID","i")>0 then tsvalnum = 1;
  IF find(_name_,"DOMAIN",'i')>0 then tsvalnum = 2;
  IF find(_name_,"TSSEQ",'i')>0 then tsvalnum = 3;
  IF find(_name_,"TSGRPID",'i')>0 then tsvalnum = 4;
  IF find(_name_,"TSPARMCD",'i')>0 then tsvalnum = 5;
  IF find(_name_,"TSPARM",'i')>0 then tsvalnum = 6;
  IF find(_name_,"TSVAL",'i')>0 then tsvalnum = 7;
  IF find(_name_,"TSVALNF",'i')>0 then tsvalnum = 8;
  IF find(_name_,"TSVALCD",'i')>0 then tsvalnum = 9;
  IF find(_name_,"TSVCDREF",'i')>0 then tsvalnum = 10;
  IF find(_name_,"TSVCDVER",'i')>0 then tsvalnum = 11;
run;
 
proc sort data= source.ts6 out = source.ts7;
by tsvalnum _name_;
run;



proc sql noprint;
 select _name_ into : list separated by ' '
  from source.ts7;
quit;


data _null_;
%put &list;
run;

data source.ts8;
format &list;
set source.ts2;
run;

%let st = TSVAL;
%let vl = Parameter Value;
%let nvars_ts = %nvars(source.ts8);


data source.ts10;
format &list;
set Empty_TS source.ts8;
label %VarLabels(Var=&st, Start=1, NVars=&nvars_ts, Label=&vl) ;
run;

data target.ts;
set source.ts10;
run;

**** SORT TS ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TS) 

proc sort data=target.ts; 
by &TSSORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.TS file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\TS.xpt" ; 
run;
