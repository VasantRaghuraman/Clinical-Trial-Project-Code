/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: ADSL
Programmers: Vasant Raghuraman
Date: July 15, 2019
Project: Practice Project in Oncology
Raw Dataset: Target.DM
************************************************************************************************/
%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_ADSL Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\ADAM Submission\Excel Files\ADAM Variable_Metadata.csv,dataset=ADSL)

/*Try to extract all variable names in work.Empty_ADSL to source.ADSL1 to help create format statement below*/
proc transpose data = work.Empty_ADSL(obs=0) out=source.ADSL1;
var _all_;
run;

proc sql noprint;
 select _NAME_ into : list separated by ' '
  from source.ADSL1;
quit;

data _null_;
%put &list;
run;

%mergsupp(sourcelib=target, outlib=source, domains=DM);

proc sql;
create table source.ADSL3 as
select DM.STUDYID, DM.DOMAIN, DM.USUBJID, DM.SUBJID as SUBJID, DM.SITEID as SITEID label="Study Site Identifier", DM.REGION as REGION1 label="Geographic Region 1", DM.AGE, DM.AGEU, DM.SEX, DM.RACE,
       DM.SAFETY as SAFFL label="Safety Population Flag", DM.ITT as ITTFL label="Intent-To-Treat Population Flag", 
       DM.RANDOM as RANDFL label="Randomized Population Flag", (case when DM.DTHFL="Y" then "Y" else "N" end) as DTHFL, DM.ARM, DM.ACTARM, DM.RFICDTC, DM.DTHDTC,DM.AGEC
from source.DM as DM;
quit;

data source.ADSL4(drop=RFICDTC RFICDTM DTHDTC DTHDT);
set source.ADSL3;
format STUDYID DOMAIN USUBJID SITEID REGION1 AGE AGEU SEX RACE SAFFL ITTFL RANDFL DTHFL ARM ACTARM  RFICDT RANDDT DTHDTM;
%dtc2dt(RFICDTC,prefix=RFIC);
%dtc2dt(DTHDTC, prefix=DTH);
RANDDT=.;
if DTHDTM = . and DTHDT ne . then DTHTMF="H";
if DTHDTM=. then DTHDTM=DTHDT*24*60*60;
if DTHFL="Y" and DTHDTM=. then DTHDTF="Y";
else DTHDTF="";
run;

data source.ADSLEX1;
set target.EX;
%dtc2dt(EXSTDTC,prefix=EXST);
%dtc2dt(EXENDTC,prefix=EXEN);
run;

proc sort data=source.ADSLEX1 out=source.ADSLEX2;
by USUBJID EPOCH EXTPTNUM EXTRT EXSTDTM EXSTDT;
run;

/*Impute timepart for incomplete dates. then datetime is the same as maximum datetime of another record with complete datetime
having same USUBJID EPOCH EXTPTNUM EXSTDT else datetime is beginning of day calculated by multiplying date by 24*60*60*/
data source.ADSLEX3(keep=USUBJID EPOCH EXTPTNUM EXSTDT EXSTDTM EXENDT EXENDTM EXSTDTMnew EXENDTMnew EXTPTNUMmin);
set source.ADSLEX2;
by USUBJID EPOCH EXTPTNUM EXTRT EXSTDTM EXSTDT;
retain EXSTDTMnew EXENDTMnew EXTPTNUMmin;
if first.Epoch and first.EXTPTnum then EXTPTNUMmin=EXTPTNUM;
if first.EXTPTNUM then do;
EXSTDTMnew=.;
EXENDTMnew=.;
end;
if EXSTDTM ne . then EXSTDTMnew =EXSTDTM;
if EXENDTM ne . then EXENDTMnew=EXENDTM;
if EXSTDTM= . and EXSTDTMnew= . and EXSTDT ne . then EXSTDTMnew=EXSTDT*24*60*60;
if EXENDTM= . and EXENDTMnew= . and EXENDT ne . then EXENDTMnew=EXENDT*24*60*60;
if last.EXTPTNUM;
run;

proc sql;
create table source.ADSLEX4 as
select AD2.*,AD3.EXSTDTMnew, AD3.EXENDTMnew, AD3.EXTPTNUMmin
from source.ADSLEX2 as AD2
left join
source.ADSLEX3 as AD3
on AD2.USUBJID=AD3.USUBJID and AD2.EPOCH=AD3.EPOCH and AD2.EXTPTNUM=AD3.EXTPTNUM;
quit;

data source.ADSLEX5(drop=EXSTDT EXENDT EXSTDTMnew EXENDTMnew STUDYID DOMAIN EXSEQ EXTRT EXDOSE EXDOSU EXDOSFRM
                    EXSTDTC EXENDTC EXDUR EXTPT EXSTDY EXENDY);
set source.ADSLEX4;
if EXSTDTM = . and EXSTDT ne . then do;
EXSTDTM=EXSTDTMnew;
TRTSTMF="H";
end;
if EXENDTM = . and EXENDT ne . then do;
EXENDTM=EXENDTMnew;
TRTENTMF="H";
end;
if TRTSTMF="H" or TRTENTMF="H";
run;

/*Take advantage of the fact that the time is imputed for EXSTDTM and EXENDTM for the same row simultaneously. Normally
it would be done separately for EXSTDT*/
proc sql;
create table source.ADSLEX6 as
select distinct AD4.USUBJID,AD4.EXSEQ,AD4.EPOCH,AD4.EXTPTNUM,AD4.EXSTDTMnew as EXSTDTM format=datetime19., 
                AD4.EXENDTMnew as EXENDTM format=datetime19., AD4.EXTPTNUMmin,AD5.TRTSTMF,AD5.TRTENTMF
from source.ADSLEX4 as AD4
left join
source.ADSLEX5 as AD5
on AD4.USUBJID=AD5.USUBJID and AD4.EPOCH=AD5.EPOCH and AD4.EXTPTNUM=AD5.EXTPTNUM;
quit;

proc sort data=source.ADSLEX6 nodupkey;
by USUBJID EXSEQ;
run;

/*Only the first and last dates in each cycle are needed. Dates for first EXSTDTM in first Timepoint of each cycle
and last Timepoint of last cycle and last EXENDTM are first extracted.
Only corresponding missing dates need to be imputed for TRT variables.
Imputation of dates is carried out as follows: if timepoint to be imputed is the first in cycle then , 
datetime is(cyclenum of missing datetime-cyclenum of previous non-missing date)*(29-previous tptnum)*24*60*60+previous datetime in case USUBJID is same as previous tptnum. 
if timepoint to be imputed is not first in cycle then datetime is(current tptnum-previous tptnum)*24*60*60 .
This is done because each cycle is 4 weeks in case USUBJID is same as previous tptnum. 
If in either case, the imputed date is greater than next date in same USUBJID then date imputed is average(last non-missing date and
next non-missing date) */
proc sql;
create table source.ADSLEX7 as
select USUBJID,EPOCH,max(EXTPTNUM) as EXTPTNUMmax
from source.ADSLEX6 as AD6
group by USUBJID,EPOCH;
quit;

proc sql;
create table source.ADSLEX7a as
select USUBJID,max(input(compress(EPOCH,,"as"),8.)) as EPOCHnummax,compbl("CYCLE"||" "||put(calculated EPOCHnummax,2.)) as EPOCHmax,
       min(input(compress(EPOCH,,"as"),8.)) as EPOCHnummin,compbl("CYCLE"||" "||put(calculated EPOCHnummin,2.)) as EPOCHmin
from source.ADSLEX6 as AD6
group by USUBJID;
quit;

proc sql;
create table source.ADSLEX8 as
select AD6.*, EPOCHmax,EPOCHmin,EXTPTNUMmax, input(compress(AD6.EPOCH,,"as"),8.) as EPOCHNUM
from source.ADSLEX6 as AD6
left join
source.ADSLEX7 as AD7
on AD6.USUBJID=AD7.USUBJID  and AD6.EPOCH=AD7.EPOCH
left join
source.ADSLEX7a as AD7a
on AD6.USUBJID=AD7a.USUBJID
order by USUBJID,EPOCHNUM,EXTPTNUM;
quit;

proc sql;
create table source.ADSLEX9 as
select USUBJID,EPOCH, min(EXSTDTM) as EXSTDTM format=datetime19., max(TRTSTMF) as TRTSTMF
from source.ADSLEX8 as AD8
where EXTPTNUM=EXTPTNUMmin
group by USUBJID,EPOCH;
quit;

proc sql;
create table source.ADSLEX10 as
select USUBJID,EPOCH, max(EXENDTM) as EXENDTM format=datetime19., max(TRTENTMF) as TRTENTMF
from source.ADSLEX8 as AD8
where EXTPTNUM=EXTPTNUMmax
group by USUBJID,EPOCH;
quit;

data source.ADSLEX11(rename=(TRTSTMF=TRTSTTMF));
merge source.ADSLEX9 source.ADSLEX10;
by USUBJID;
run;

/*Since dates are missing for EXENDTM, they are imputed and marked as "Y" and corresponding time flag is marked as "H"
All the days have full dates*/
data source.ADSLEX12 source.ADSLEX13(drop=EXSTDTM TRTSTTMF TRTSTDTF) source.ADSLEX14(drop=EXENDTM TRTENTMF TRTENDTF);
set source.ADSLEX11;
if EXSTDTM=. then TRTSTDTF="Y";
else TRTSTDTF="";
if EXENDTM=. then TRTENDTF="Y";
else TRTENDTF="";
if EXENDTM=. then output source.ADSLEX13;
if EXSTDTM=. then output source.ADSLEX14;
output source.ADSLEX12;
run;

/*Implement LOCF for EXSTDTM and EXENDTM for tables ADSLEX12 and ADSLEX13*/
/*First create the code for the Cycle Shell imputing the intermediate or missing Cycles in USUBJID.
Merge with dataset containing all cycles ADSLEX12. In this case, there are no intermediate missing cycles*/
data source.ADSLEX15(drop=EPOCHmax EPOCHmin EPOCHnummax EPOCHNUMmin);
set source.ADSLEX7a;
length EPOCH $40;
do EPOCHNUM = EPOCHNUMmin to EPOCHNUMmax;
EPOCH=compbl("CYCLE"||" "||put(EPOCHNUM,2.));
     do EXTPTNUM=1,8,15,22;
	    if EPOCHNUM = 1 then output; 
        if EPOCHNUM > 1 and EXTPTNUM ne 22 then output;
	 end;
end;
run;

/*If the missing dates were the last missing dates in a cycle then delete them. In this case we find that 
all missing dates are last dates in cycle*/
data source.ADSLEX16;
merge source.ADSLEX15(in=ina) source.ADSLEX8(in=inb);
by USUBJID EPOCHNUM EXTPTNUM;
if ina and not inb then NEWOBS=1;
else NEWOBS=0;
if newobs=1 and EPOCHNUM=input(compress(EPOCH,,"as"),8.) and EXTPTNUM>EXTPTNUMmax then delete;
run;

/*Implement LOCF to get previous non-missing EPOCHNUM and EXTPTNUM*/
data source.ADSLEX17 ;
set source.ADSLEX16 (keep=USUBJID EPOCH EPOCHNUM EXTPTNUM EXSTDTM EXENDTM);
length USUBJIDbaseST USUBJIDbaseEN $18;
by USUBJID ;
retain EXSTDTMbase EXENDTMbase USUBJIDbaseST EPOCHNUMbaseST EXTPTNUMbaseST USUBJIDbaseEN EPOCHNUMbaseEN EXTPTNUMbaseEN;
if first.USUBJID then do;
EXSTDTMbase=.;
USUBJIDbaseST="";
EPOCHNUMbaseST=.;
EXTPTNUMbaseST=.;
EXENDTMbase=.;
USUBJIDbaseEN="";
EPOCHNUMbaseEN=.;
EXTPTNUMbaseEN=.;
end;
if EXSTDTM ^= . then do;
   EXSTDTMbase = EXSTDTM;
   USUBJIDbaseST=USUBJID;
   EPOCHNUMbaseST=EPOCHNUM;
   EXTPTNUMbaseST=EXTPTNUM;
end;

if EXENDTM ^= . then do;
   EXENDTMbase = EXENDTM;
   USUBJIDbaseEN=USUBJID;
   EPOCHNUMbaseEN=EPOCHNUM;
   EXTPTNUMbaseEN=EXTPTNUM;
end;
run ;

data source.ADSLEX18(keep=USUBJID EPOCH EPOCHNUM EXTPTNUM EXSTDTM EXSTDTF EXENDTM EXENDTF);
set source.ADSLEX17;
if EXSTDTM=. and USUBJID=USUBJIDbaseST then do;
EXSTDTF="Y";
EXSTDTM=(((EPOCHNUM-EPOCHNUMbaseST)*28)+(EXTPTNUM-EXTPTNUMbaseST))*24*60*60+EXSTDTMbase;
end;
if EXENDTM=. and USUBJID=USUBJIDbaseEN then do;
EXENDTF="Y";
EXENDTM=(((EPOCHNUM-EPOCHNUMbaseEN)*28)+(EXTPTNUM-EXTPTNUMbaseEN))*24*60*60+EXENDTMbase;
end;
run;

proc sort data=source.ADSLEX18;
by USUBJID EPOCHNUM EXTPTNUM;
run;

/*Check if dates are ordered properly after imputation. In this case dates are ordered properly*/
data source.ADSLEX19;
set source.ADSLEX18;
by USUBJID EPOCHNUM EXTPTNUM;
USUBJIDprev=lag(USUBJID);
EXSTDTMprev=lag(EXSTDTM);
EXENDTMprev=lag(EXENDTM);
if EXSTDTM<EXSTDTMprev and USUBJID=USUBJIDprev then output source.ADSLEX19;
if EXENDTM<EXENDTMprev and USUBJID=USUBJIDprev then output source.ADSLEX19;
run;

data source.ADSLEX18a;
merge source.ADSLEX16 source.ADSLEX18;
by USUBJID EPOCHNUM EXTPTNUM;
if EXSTDTF="Y" then TRTSTMF="H";
if EXENDTF="Y" then TRTENTMF="H";
if TRTSTMF="H" then TRTSTMFnum=1; else TRTSTMFnum=0;
if TRTENTMF="H" then TRTENTMFnum=1; else TRTENTMFnum=0;
if EXSTDTF="Y" then TRTSTDTFnum=1; else TRTSTDTFnum=0;
if EXENDTF="Y" then TRTENDTFnum=1; else TRTENDTFnum=0;
run;

proc sql;
create table source.ADSLEX19 as
select USUBJID,EPOCH,EPOCHNUM,min(EXSTDTM) as TRTSTDTM, max(EXENDTM) as TRTENDTM
from source.ADSLEX18 as AD18
group by USUBJID, EPOCHNUM, EPOCH
order by USUBJID,EPOCHNUM,EPOCH;
quit;

proc sql;
create table source.ADSLEX19a as
select USUBJID,EPOCHNUM,EPOCH,
       (select max(TRTSTDTFnum) from source.ADSLEX18a as AD18new where  AD18.USUBJID=AD18new.USUBJID and AD18.EPOCHNUM=AD18new.EPOCHNUM
	      and AD18new.EXTPTNUM=AD18.EXTPTNUMmin) as TRTSTDTFnum,
		  /*(case when calculated TRTSTDTFnum=1 then "Y" else "" end) as TRTSTDTF,*/
       (select max(TRTSTMFnum) from source.ADSLEX18a as AD18new where  AD18.USUBJID=AD18new.USUBJID and AD18.EPOCHNUM=AD18new.EPOCHNUM
	      and AD18new.EXTPTNUM=AD18.EXTPTNUMmin) as TRTSTTMFnum,
		  (case when calculated TRTSTTMFnum=1 then "H" else "" end) as TRTSTTMF,
       (select max(TRTENDTFnum) from source.ADSLEX18a as AD18new where  AD18.USUBJID=AD18new.USUBJID and AD18.EPOCHNUM=AD18new.EPOCHNUM
	      and AD18new.EXTPTNUM=AD18.EXTPTNUMmax) as TRTENDTFnum,
		  /*(case when calculated TRTENTMFnum=1 then "H" else "" end) as TRTENTMF,*/
       (select max(TRTENTMFnum) from source.ADSLEX18a as AD18new where  AD18.USUBJID=AD18new.USUBJID and AD18.EPOCHNUM=AD18new.EPOCHNUM
	      and AD18new.EXTPTNUM=AD18.EXTPTNUMmax) as TRTENTMFnum,
		  (case when calculated TRTENTMFnum=1 then "H" else "" end) as TRTENTMF
from source.ADSLEX18a as AD18
order by USUBJID,EPOCHNUM,EPOCH;
quit;

proc sql;
create table source.ADSLEX19b as
select USUBJID,EPOCHNUM,EPOCH, 
       max(TRTSTDTFnum) as TRTSTDTFnum, (case when calculated TRTSTDTFnum=1 then "Y" else "" end) as TRTSTDTF,
       max(TRTSTTMFnum) as TRTSTTMFnum, (case when calculated TRTSTTMFnum=1 then "H" else "" end) as TRTSTTMF,
       max(TRTENDTFnum) as TRTENDTFnum, (case when calculated TRTENDTFnum=1 then "Y" else "" end) as TRTENDTF,
       max(TRTENTMFnum) as TRTENTMFnum, (case when calculated TRTENTMFnum=1 then "H" else "" end) as TRTENTMF
from source.ADSLEX19a
group by USUBJID,EPOCHNUM,EPOCH
order by USUBJID,EPOCHNUM,EPOCH;
quit;

data source.ADSLEX20(drop=TRTSTTMFnum TRTENTMFnum TRTSTDTFnum TRTENDTFnum);
merge source.ADSLEX19 source.ADSLEX19b;
by USUBJID EPOCHNUM EPOCH;
run;

proc transpose data=source.ADSLEX20(drop=TRTENDTM TRTSTTMF TRTENTMF TRTSTDTF TRTENDTF) out=source.ADSLEX21(drop=_NAME_) prefix=STDTM_;
var TRTSTDTM;
by USUBJID;
id EPOCH;
run;

proc transpose data=source.ADSLEX20(drop=TRTSTDTM TRTSTTMF TRTENTMF TRTSTDTF TRTENDTF) out=source.ADSLEX22(drop=_NAME_) prefix=ENDTM_;
var TRTENDTM;
by USUBJID;
id EPOCH;
run;

proc transpose data=source.ADSLEX20(drop=TRTSTDTM TRTENDTM TRTENTMF TRTSTTMF TRTENDTF) out=source.ADSLEX23a(drop=_NAME_) prefix=STDTF_;
var TRTSTDTF;
by USUBJID;
id EPOCH;
run;

proc transpose data=source.ADSLEX20(drop=TRTSTDTM TRTENDTM TRTENTMF TRTSTDTF TRTENDTF) out=source.ADSLEX23b(drop=_NAME_) prefix=STTMF_;
var TRTSTTMF;
by USUBJID;
id EPOCH;
run;

proc transpose data=source.ADSLEX20(drop=TRTSTDTM TRTENDTM TRTSTTMF TRTSTDTF TRTENTMF) out=source.ADSLEX24a(drop=_NAME_) prefix=ENDTF_;
var TRTENDTF;
by USUBJID;
id EPOCH;
run;

proc transpose data=source.ADSLEX20(drop=TRTSTDTM TRTENDTM TRTSTTMF TRTSTDTF TRTENDTF) out=source.ADSLEX24b(drop=_NAME_) prefix=ENTMF_;
var TRTENTMF;
by USUBJID;
id EPOCH;
run;

data source.ADSLEX25;
merge source.ADSLEX21 source.ADSLEX22 source.ADSLEX23a source.ADSLEX23b source.ADSLEX24a source.ADSLEX24b;
by USUBJID;
run;

proc transpose data = source.ADSLEX25(obs=0) out=source.ADSLEX26;
var _all_;
run;


proc transpose data = Empty_ADSL(obs=0) out=source.ADSLEX27;
var _all_;
run;

data source.ADSLEX28;
set source.ADSLEX27;
if index(_NAME_,'TR')>0 and  index(_NAME_,'SDTM')>0 and index(_NAME_,'TRTSDTM')=0 then do;
ordernum=1;
output;
end;
if index(_NAME_,'TR')>0 and  index(_NAME_,'EDTM')>0 and index(_NAME_,'TRTEDTM')=0 then do;
ordernum=2;
output;
end;
if index(_NAME_,'TR')>0 and  index(_NAME_,'SDTF')>0 and index(_NAME_,'TRTSDTF')=0 then do;
ordernum=3;
output;
end;
if index(_NAME_,'TR')>0 and  index(_NAME_,'STMF')>0 and index(_NAME_,'TRTSTMF')=0 then do;
ordernum=4;
output;
end;
if index(_NAME_,'TR')>0 and  index(_NAME_,'EDTF')>0 and index(_NAME_,'TRTEDTF')=0 then do;
ordernum=5;
output;
end; 
if index(_NAME_,'TR')>0 and  index(_NAME_,'ETMF')>0 and index(_NAME_,'TRTETMF')=0 then do;
ordernum=6;
output;
end; 
run;

proc sql(drop=ordernum);
create table source.ADSLEX29 as
select * from source.ADSLEX28
order by ordernum,_NAME_;
quit;

proc transpose data=source.ADSLEX25(obs=0 drop=USUBJID) out=source.ADSLEX30;
var _ALL_;
run;

data source.ADSLEX31;
merge source.ADSLEX30(rename=(_NAME_=Old_Variable)) source.ADSLEX29(rename=(_NAME_=New_Variable _LABEL_=New_Label));
newlabel1="'"||New_Label||"'";
run;

proc sql;
select Old_Variable||"="||New_Variable into:rename_list separated by " "
from source.ADSLEX31;
quit; 

proc sql;
select New_Variable||"="||newlabel1 into:Label_List separated by " "
from source.ADSLEX31;
quit; 

proc datasets library = source nolist;
modify ADSLEX25;
rename &rename_list;
label &Label_List;
quit;


data source.ADSLEX32(drop=CYCNO);
set source.ADSLEX27;
CYCNO=input(compress(_NAME_,,"as"),3.);
if CYCNO>0 and CYCNO<20 then do;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'SDTM')>0 or index(_NAME_,'SDM')>0) then do;
ordernum=1;
output;
end;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'EDTM')>0 or index(_NAME_,'EDM')>0) then do;
ordernum=2;
output;
end;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'SDTF')>0 or index(_NAME_,'SDF')>0) then do;
ordernum=3;
output;
end;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'STMF')>0 or index(_NAME_,'SMF')>0) then do;
ordernum=4;
output;
end;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'EDTF')>0 or index(_NAME_,'EDF')>0) then do;
ordernum=5;
output;
end;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'ETMF')>0 or index(_NAME_,'EMF')>0) then do;
ordernum=6;
output;
end;
end;
run;

proc sql(drop=ordernum);
create table source.ADSLEX33 as
select AD32.*, input(compress(_NAME_,,"as"),3.) as CYCNO
from source.ADSLEX32 as AD32
order by ordernum,CYCNO;
quit;

proc transpose data=source.ADSLEX25(obs=0 drop=USUBJID) out=source.ADSLEX34;
var _ALL_;
run;

data source.ADSLEX35;
merge source.ADSLEX34(rename=(_NAME_=Old_Variable)) source.ADSLEX33(rename=(_NAME_=New_Variable _LABEL_=New_Label));
New_Label=compbl(New_Label);
newlabel1=compbl("'"||New_Label||"'");
run;

proc sql;
select Old_Variable||"="||New_Variable into:rename_list separated by " "
from source.ADSLEX35;
quit; 

proc sql;
select New_Variable||"="||newlabel1 into:Label_List separated by " "
from source.ADSLEX35;
quit; 

data source.ADSLEX36;
set source.ADSLEX25;
run;

proc datasets library = source nolist;
modify ADSLEX36;
rename &rename_list;
label &Label_List;
quit;

/*In the case of Analysis Cycle during the treatment period, the End date should be 1 second prior to the start
of the next cycle. For the last dosing cycle, the End date would be one second prior to the start of the first follow up or withdrawal
cycle which shall be obtained in future data steps in this program. The corrspoding date and time flags are updated to "Y" and
"H" respectively to reflect the imputation.*/

/*WE shall use arrays or proc iml for trial purpose */


proc transpose data=source.ADSLEX36(obs=0) out=source.ADSLEX37;
var _ALL_;
run;

data source.ADSLEX37a source.ADSLEX37b source.ADSLEX37c source.ADSLEX37d;
set source.ADSLEX37;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'SDTM')>0 or index(_NAME_,'SDM')>0) then output source.ADSLEX37a;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'EDTM')>0 or index(_NAME_,'EDM')>0) then output source.ADSLEX37b;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'EDTF')>0 or index(_NAME_,'EDF')>0) then output source.ADSLEX37c;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'ETMF')>0 or index(_NAME_,'EMF')>0) then output source.ADSLEX37d;
run;

proc sql noprint;
select _NAME_ into:SDTM_List separated by " "
from source.ADSLEX37a;
quit;

proc sql noprint;
select _NAME_ into:EDTM_List separated by " "
from source.ADSLEX37b;
quit;

proc sql noprint;
select _NAME_ into:EDTF_List separated by " "
from source.ADSLEX37c;
quit;

proc sql noprint;
select _NAME_ into:ETMF_List separated by " "
from source.ADSLEX37d;
quit;

data _null_;
%put &SDTM_list;
%put &EDTM_list;
%put &EDTF_list;
%put &ETMF_list;
run;

data source.ADSLEX38;
set source.ADSLEX36;
ARRAY SDTM[19] &SDTM_list;
ARRAY EDTM[19] &EDTM_list;
ARRAY EDTF[19] $1 &EDTF_list;
ARRAY ETMF[19] $1 &ETMF_list;
do i=1 to 18;
EDTM[i]=SDTM[i+1]-1;
	if EDTM[i] ne . then do;
	EDTF[i]="Y";
	ETMF[i]="S";
	end;
	else do;
	EDTF[i]="";
	ETMF[i]="";
end;
end;
format &SDTM_list &EDTM_list datetime16.;
run;

data source.ADSL5;
Length Value $40;
set source.ADSL1;
if index(_NAME_,'ACYCLE')>0 ;
if input(compress(_NAME_,,"as"),2.)=0 then Value="Screening Cycle";
if input(compress(_NAME_,,"as"),2.)>0 and input(compress(_NAME_,,"as"),2.)<20  
             then Value=compbl("Treatment Cycle "||input(compress(_NAME_,,"as"),2.));
if input(compress(_NAME_,,"as"),2.)=20   
             then Value="End of Treatment or Withdrawal";
if input(compress(_NAME_,,"as"),2.)=21   
             then Value="First Follow-Up After Treatment";
if input(compress(_NAME_,,"as"),2.)>21   
             then Value=compbl("Follow-Up"||input(compress(_NAME_,,"as"),8.)-20);
run;

proc transpose data=source.ADSL5 out=source.ADSL6(drop=_NAME_) name=_NAME_;
var Value;
idlabel _LABEL_;
run;

data source.ADSL6(drop=i);
   do i = 1 to 273;
      do j = 1 to n;
         set source.ADSL6 nobs=n point=j;
         output;
         end;
      end;
   stop;
   run;

data source.ADSL7;
set source.ADSL1;
where _NAME_ like "TRT__P";
run;


proc sql noprint;
select _NAME_ into:TRTP_List separated by " "
from source.ADSL7;
quit;

proc sql noprint;
select _NAME_||"=ARM;" into:TRTAssign_List separated by " "
from source.ADSL7;
quit;

data source.ADSL7a;
set source.ADSL1;
where _NAME_ like "TRT__PN";
run;

proc sql noprint;
select _NAME_ into:TRTPN_List separated by " "
from source.ADSL7a;
quit;

data source.ADSL8(drop=ARM i);
format USUBJID &TRTP_List &TRTPN_list;
length &TRTP_List $20;
set target.DM(keep=USUBJID ARM);
ARRAY TRTPN[19] &TRTPN_List;
ARRAY TRTP[19] $ &TRTP_List;
&TRTAssign_List;
do i=1 to 19;
if TRTP[i]="PLACEBO" then TRTPN[i]=0;
else TRTPN[i]=1;
end;
run;

proc sql noprint;
select _NAME_ into:SDTMcma_List separated by ","
from source.ADSLEX37a;
quit;

data source.ADSL9(keep=USUBJID COUNT);
set source.ADSLEX38;
COUNT=N(of &SDTMcma_List);
run;

proc sql;
create table source.ADSL10 as
select AD8.*,COUNT
from source.ADSL8 as AD8
left join
source.ADSL9 as AD9
on AD8.USUBJID=AD9.USUBJID;
quit;


data source.ADSL11(drop= i COUNT);
format USUBJID &TRTP_List &TRTPN_list;
length &TRTP_List $20;
set source.ADSL10;
ARRAY TRTPN[19] &TRTPN_List;
ARRAY TRTP[19] $ &TRTP_List;
if COUNT=. then COUNT=0;
do i=1 to 19;
if i>COUNT then do;
TRTP[i]="";
TRTPN[i]=.;
end;
end;
run;


proc sql;
create table source.ADSLEX39 as
select USUBJID,EXTRT,EPOCH,EXDOSE as ActDose,(case when EX.EXTRT="4MG AFLIBERCEPT" then 4 else 0 end)as PlnDose,EXDOSU
from target.EX as EX
where EXTRT in('PLACEBO','4MG AFLIBERCEPT')
order by USUBJID,EXTRT,EPOCH;
quit;

/*There are no missing dosing dates as per the calculation in source.ADSLEX16.So shell remains same.
Implement WOCF for missing values*/
proc sql;
create table source.ADSLEX40 as
select AD39.*,min(ActDose) as ActDoseWOCF
from source.ADSLEX39 as AD39
group by USUBJID;
quit;

data source.ADSLEX41(drop=ActDoseWOCF);
set source.ADSLEX40;
if ActDose=. then ActDose=ActDoseWOCF;
run;

proc sql;
create table source.ADSLEX42 as
select USUBJID, EPOCH, sum(ActDose) as Actdose, sum(PlnDose) as PlnDose, EXDosU as DOSU
from source.ADSLEX41 as AD41
group by USUBJID, EPOCH, DOSU;
quit; 

proc transpose data=source.ADSLEX42(keep=USUBJID EPOCH ACTDOSE) out=source.ADSLEX43a(drop=_NAME_) prefix=ACT;
by USUBJID;
var ActDose;
id EPOCH;
run;

proc transpose data=source.ADSLEX42(keep=USUBJID EPOCH PlnDose) out=source.ADSLEX43b(drop=_NAME_) prefix=Pln;
by USUBJID;
var PlnDose;
id EPOCH;
run;

proc transpose data=source.ADSLEX42(keep=USUBJID EPOCH DOSU) out=source.ADSLEX43c(drop=_NAME_ _LABEL_) prefix=DOSU;
by USUBJID;
var DOSU;
id EPOCH;
run;

data source.ADSLEX43d;
merge source.ADSLEX43a source.ADSLEX43b source.ADSLEX43c;
by USUBJID;
run;
 
data source.ADSLEX44a source.ADSLEX44b source.ADSLEX44c;
set source.ADSL1;
if index(_NAME_,'DOSE')>0 and index(_NAME_,'A')>0 then output source.ADSLEX44a;
if index(_NAME_,'DOSE')>0 and index(_NAME_,'P')>0 then output source.ADSLEX44b;
if index(_NAME_,'DOSE')>0 and index(_NAME_,'U')>0 then output source.ADSLEX44c;
run;

data source.ADSLEX45;
set source.ADSLEX44a source.ADSLEX44b source.ADSLEX44c;
run;

proc transpose data=source.ADSLEX43d(obs=0 drop=USUBJID) out=source.ADSLEX46;
var _ALL_;
run;

data source.ADSLEX47;
merge source.ADSLEX46(rename=(_NAME_=Old_Variable)) source.ADSLEX45(rename=(_NAME_=New_Variable _LABEL_=New_Label));
newlabel1="'"||New_Label||"'";
run;

proc sql noprint;
select Old_Variable||"="||New_Variable into:rename_list1 separated by " "
from source.ADSLEX47;
quit; 

proc sql noprint;
select New_Variable||"="||newlabel1 into:Label_List1 separated by " "
from source.ADSLEX47;
quit; 

proc datasets library = source nolist;
modify ADSLEX43d;
rename &rename_list1;
label &Label_List1;
quit;

data source.ADSL12(keep=USUBJID VISITNUM SVSTDTM SVENDTM);
set target.SV;
%dtc2dt(SVSTDTC,prefix=SVST);
%dtc2dt(SVENDTC,prefix=SVEN);
if SVSTDTM=. then SVSTDTM=SVSTDT*24*60*60;
if SVENDTM=. then SVENDTM=SVENDT*24*60*60+(24*60*60-1);
if VISITNUM <100 and mod(VISITNUM,1)=0;
run;

/*Impute misssing Visitnum between 80 and last visitnum if missing*/

proc sql;
create table source.ADSL13 as
select USUBJID, max(VISITNUM) as VISITNUMmax
from source.ADSL12 as AD12
group by USUBJID
having max(VISITNUM)>20;
quit;

data source.ADSL14(drop=VISITNUMmax);
retain USUBJID;
set source.ADSL13;
do VISITNUM=80 to VISITNUMmax;
output;
end;
run;

data source.ADSL15;
merge source.ADSL14 source.ADSL12;
by USUBJID VISITNUM;
run;

data source.ADSL15a(keep=USUBJID VISITNUM SVSTdtm SVENDTM);
set source.ADSLEX20;
VISITNUM=EPOCHNUM;
SVSTdtm=TRTSTdtm;
SVENdtm=TRTENdtm;
run;

data source.ADSL15b;
merge source.ADSL15 source.ADSL15a;
by USUBJID VISITNUM;
run;

%locfrb(inds=source.ADSL15b,outds=source.ADSL16,byvars=USUBJID VISITNUM,groupvar=USUBJID,var=SVSTdtm, newvar=SVSTdtmprev,dir=F)

%locfrb(inds=source.ADSL16,outds=source.ADSL16a,byvars=USUBJID VISITNUM,groupvar=USUBJID,var=SVENdtm, newvar=SVENdtmprev,dir=F)

%locfrb(inds=source.ADSL16a,outds=source.ADSL17,byvars=USUBJID VISITNUM,groupvar=USUBJID,var=SVSTdtm, newvar=SVSTdtmnext,dir=R)

%locfrb(inds=source.ADSL17,outds=source.ADSL17a,byvars=USUBJID VISITNUM,groupvar=USUBJID,var=SVENdtm, newvar=SVENdtmnext,dir=R)

data source.ADSL17a;
set source.ADSL17a;
if SVSTdtm = . or SVENdtm=. then VISITNUM=.;
run;

%locfrb(inds=source.ADSL17a,outds=source.ADSL18,byvars=USUBJID,groupvar=USUBJID,var=VISITNUM, newvar=VISITNUMprev,dir=F)

%locfrb(inds=source.ADSL18,outds=source.ADSL19,byvars=USUBJID,groupvar=USUBJID,var=VISITNUM, newvar=VISITNUMnext,dir=R)

data source.ADSL20;
merge source.ADSL19 source.ADSL15b(keep=USUBJID VISITNUM);
by USUBJID;
run;

data source.ADSL21(keep=USUBJID VISITNUM SVSTdtm SVENdtm STImputed);
set source.ADSL20;
if VISITNUMprev<30 and VISITNUM>=80 then VISITNUMprevfwd=79; 
else VISITNUMprevfwd=VISITNUMprev;
if SVSTdtm=. then do;
STImputed=1;
SVSTdtm=max(SVSTdtmprev,SVENdtmprev)+((min(SVSTdtmnext,SVENdtmnext)-max(SVSTdtmprev,SVENdtmprev))/(VISITNUMnext-VISITNUMprevfwd)*(VISITNUM-VISITNUMprevfwd));
end;
else STImputed=0;
run;

data source.ADSL21a;
  obs1 = 1;
  do while( obs1 <= nobs);
    set source.ADSL21 nobs=nobs;
    obs2 = obs1 + 1;
    set source.ADSL21(rename=(USUBJID=USUBJIDnext VISITNUM=VISITNUMnext SVSTdtm=SVSTdtmnext SVENdtm=SVENdtmnext
                              STImputed=STImputednext)) point=obs2;
    if USUBJID=USUBJIDnext then SVENdtm=SVSTdtmnext-1;
	ENImputed=1;
    output;
    obs1 + 1;
  end;
  drop USUBJIDnext VISITNUMnext SVSTdtmnext SVENdtmnext STImputednext SVSTdtmnext;
run;

/*Since the End Date and time will be imputed to 1 second earlier than the start of the next cycle*/
data source.ADSL22(drop=STImputed ENImputed obs1);
set source.ADSL21a;
if STImputed = 1 then do;
STDF="Y";
STMF="H";
end;
else if VISITNUM=0 or VISITNUM>79 then STMF="H";
if ENImputed = 1 then do;
ENDF="Y";
ENMF="H";
end;
run;

data source.ADSL22a(keep=USUBJID VISITNUM STDF STMF ENDF ENMF);
set source.ADSLEX20;
VISITNUM=EPOCHNUM;
STDF=TRTSTDTF;
STMF=TRTSTTMF;
ENDF=TRTENDTF;
ENMF=TRTENTMF;
run;

proc sql;
create table source.ADSL22b as
select AD22.USUBJID, AD22.VISITNUM, AD22.SVSTDTM, AD22.SVENdtm, coalesce(AD22.STDF,AD22a.STDF) as STDF,
       coalesce(AD22.STMF,AD22a.STMF) as STMF, coalesce(AD22.ENDF,AD22a.ENDF) as ENDF, coalesce(AD22.ENMF,AD22a.ENMF) as ENMF
from source.ADSL22 as AD22
left join
source.ADSL22a as AD22a
on AD22.USUBJID=AD22a.USUBJID and AD22.VISITNUM=AD22a.VISITNUM;
quit;


proc transpose data=source.ADSL22b out=source.ADSL23a(drop=_NAME_ _LABEL_) prefix=CYCLE;
var VISITNUM;
by USUBJID;
id VISITNUM;
run;

proc transpose data=source.ADSL22b out=source.ADSL23b(drop=_NAME_) prefix=STCYCLE;
var SVSTdtm;
by USUBJID;
id VISITNUM;
run;

proc transpose data=source.ADSL22b out=source.ADSL23c(drop=_NAME_) prefix=ENCYCLE;
var SVENdtm;
by USUBJID;
id VISITNUM;
run;

proc transpose data=source.ADSL22b out=source.ADSL23d(drop=_NAME_) prefix=STDF;
var STDF;
by USUBJID;
id VISITNUM;
run;

proc transpose data=source.ADSL22b out=source.ADSL23e(drop=_NAME_) prefix=STMF;
var STMF;
by USUBJID;
id VISITNUM;
run;

proc transpose data=source.ADSL22b out=source.ADSL23f(drop=_NAME_) prefix=ENDF;
var ENDF;
by USUBJID;
id VISITNUM;
run;

proc transpose data=source.ADSL22b out=source.ADSL23g(drop=_NAME_) prefix=ENMF;
var ENMF;
by USUBJID;
id VISITNUM;
run;

data source.ADSL24;
merge source.ADSL23b source.ADSL23c source.ADSL23d source.ADSL23e source.ADSL23f source.ADSL23g;
by USUBJID;
run;

proc transpose data=source.ADSL24(obs=0 drop=USUBJID) out=source.ADSL25;
var _ALL_;
run;

data source.ADSL25a source.ADSL25b source.ADSL25c source.ADSL25d source.ADSL25e source.ADSL25f;
set source.ADSL25;
if index(_NAME_,'STCY')>0  then do;
join="SDTM";
output source.ADSL25a;
end;
if index(_NAME_,'ENCY')>0 then do;
join="EDTM";
output source.ADSL25b;
end;
if index(_NAME_,'STDF')>0 then do;
join="SDTF";
output source.ADSL25c;
end;
if index(_NAME_,'STMF')>0 then do;
join="STMF";
output source.ADSL25d;
end;
if index(_NAME_,'ENDF')>0 then do;
join="EDTF";
output source.ADSL25e;
end;
if index(_NAME_,'ENMF')>0  then do;
join="ENMF";
output source.ADSL25f;
end;
run;

data source.ADSL25g;
set source.ADSL25a source.ADSL25b source.ADSL25c source.ADSL25d source.ADSL25e source.ADSL25f;
CYCNUM=input(compress(_NAME_,,"as"),8.);
run;

proc sort data=source.ADSL25g;
by join CYCNUM;
run;

data source.ADSL26a source.ADSL26b source.ADSL26c source.ADSL26d source.ADSL26e source.ADSL26f source.ADSL26g;
set source.ADSL1;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'SDTM')>0 or index(_NAME_,'SDM')>0) then do;
join="SDTM";
output source.ADSL26a;
end;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'EDTM')>0 or index(_NAME_,'EDM')>0) then do;
join="EDTM";
output source.ADSL26b;
end;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'SDTF')>0 or index(_NAME_,'SDF')>0) then do;
join="SDTF";
output source.ADSL26c;
end;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'STMF')>0 or index(_NAME_,'SMF')>0) then do;
join="STMF";
output source.ADSL26d;
end;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'EDTF')>0 or index(_NAME_,'EDF')>0) then do;
join="EDTF";
output source.ADSL26e;
end;
if index(_NAME_,'ACY')>0 and (index(_NAME_,'ETMF')>0 or index(_NAME_,'EMF')>0) then do;
join="ENMF";
output source.ADSL26f;
end;
if substr(_NAME_,1,6)='ACYCLE' then output source.ADSL26g;
run;

data source.ADSL27;
set source.ADSL26a source.ADSL26b source.ADSL26c source.ADSL26d source.ADSL26e source.ADSL26f;
if input(compress(_NAME_,,"as"),8.)<20 then CYCNUM=input(compress(_NAME_,,"as"),8.);
else CYCNUM=input(compress(_NAME_,,"as"),8.)+60;
run;

proc sort data=source.ADSL27;
by join CYCNUM;
run;

data source.ADSL28;
merge source.ADSL25g(rename=(_NAME_=Old_Variable)) source.ADSL27(rename=(_NAME_=New_Variable _LABEL_=New_Label));
by join CYCNUM;
newlabel1=compbl("'"||New_Label||"'");
run;

proc sql noprint;
select Old_Variable||"="||New_Variable into:rename_list3 separated by " "
from source.ADSL28;
quit; 

proc sql noprint;
select New_Variable||"="||newlabel1 into:Label_List3 separated by " "
from source.ADSL28;
quit; 

proc datasets library = source nolist;
modify ADSL24;
rename &rename_list3;
label &Label_List3;
quit;

data source.ADSL29;
merge source.ADSL6 source.ADSL24;
run;

%let fmtlist1= USUBJID ACYCLE0 ACY0SDTM ACY0SDTF ACY0STMF
ACY0EDTM ACY0EDTF ACY0ETMF ACYCLE1 ACY1SDTM ACY1SDTF ACY1STMF ACY1EDTM ACY1EDTF ACY1ETMF ACYCLE2 ACY2SDTM ACY2SDTF ACY2STMF ACY2EDTM ACY2EDTF ACY2ETMF ACYCLE3 ACY3SDTM ACY3SDTF ACY3STMF ACY3EDTM ACY3EDTF ACY3ETMF ACYCLE4 ACY4SDTM ACY4SDTF ACY4STMF
ACY4EDTM ACY4EDTF ACY4ETMF ACYCLE5 ACY5SDTM ACY5SDTF ACY5STMF ACY5EDTM ACY5EDTF ACY5ETMF ACYCLE6 ACY6SDTM ACY6SDTF ACY6STMF ACY6EDTM ACY6EDTF ACY6ETMF ACYCLE7 ACY7SDTM ACY7SDTF ACY7STMF ACY7EDTM ACY7EDTF ACY7ETMF ACYCLE8 ACY8SDTM ACY8SDTF ACY8STMF
ACY8EDTM ACY8EDTF ACY8ETMF ACYCLE9 ACY9SDTM ACY9SDTF ACY9STMF ACY9EDTM ACY9EDTF ACY9ETMF ACYCLE10 ACY10SDM ACY10SDF ACY10SMF ACY10EDM ACY10EDF ACY10EMF ACYCLE11 ACY11SDM ACY11SDF ACY11SMF ACY11EDM ACY11EDF ACY11EMF ACYCLE12 ACY12SDM ACY12SDF ACY12SMF
ACY12EDM ACY12EDF ACY12EMF ACYCLE13 ACY13SDM ACY13SDF ACY13SMF ACY13EDM ACY13EDF ACY13EMF ACYCLE14 ACY14SDM ACY14SDF ACY14SMF ACY14EDM ACY14EDF ACY14EMF ACYCLE15 ACY15SDM ACY15SDF ACY15SMF ACY15EDM ACY15EDF ACY15EMF ACYCLE16 ACY16SDM ACY16SDF ACY16SMF
ACY16EDM ACY16EDF ACY16EMF ACYCLE17 ACY17SDM ACY17SDF ACY17SMF ACY17EDM ACY17EDF ACY17EMF ACYCLE18 ACY18SDM ACY18SDF ACY18SMF ACY18EDM ACY18EDF ACY18EMF ACYCLE19 ACY19SDM ACY19SDF ACY19SMF ACY19EDM ACY19EDF ACY19EMF ACYCLE20 ACY20SDM ACY20SDF ACY20SMF
ACY20EDM ACY20EDF ACY20EMF ACYCLE21 ACY21SDM ACY21SDF ACY21SMF ACY21EDM ACY21EDF ACY21EMF ACYCLE22 ACY22SDM ACY22SDF ACY22SMF ACY22EDM ACY22EDF ACY22EMF ACYCLE23 ACY23SDM ACY23SDF ACY23SMF ACY23EDM ACY23EDF ACY23EMF ACYCLE24 ACY24SDM ACY24SDF ACY24SMF
ACY24EDM ACY24EDF ACY24EMF ACYCLE25 ACY25SDM ACY25SDF ACY25SMF ACY25EDM ACY25EDF ACY25EMF ACYCLE26 ACY26SDM ACY26SDF ACY26SMF ACY26EDM ACY26EDF ACY26EMF ACYCLE27 ACY27SDM ACY27SDF ACY27SMF ACY27EDM ACY27EDF ACY27EMF ACYCLE28 ACY28SDM ACY28SDF ACY28SMF
ACY28EDM ACY28EDF ACY28EMF ACYCLE29 ACY29SDM ACY29SDF ACY29SMF ACY29EDM ACY29EDF ACY29EMF;

proc sql noprint;
select _NAME_ into:fmtlist2 separated by " "
from source.ADSL26a;
quit;

proc sql noprint;
select _NAME_ into:fmtlist3 separated by " "
from source.ADSL26g;
quit;


data source.ADSL30(drop=i);
format &fmtlist1;
length &fmtlist3 $40;
ARRAY CYCDESC [30] $ &fmtlist3;
ARRAY SDTM [30] &fmtlist2;
set source.ADSL29 ;
do i=1 to 30;
if SDTM[i]=. then CYCDESC[i]="";
end;
TRTSTDTM=ACY1SDTM;
TRTSDTF=ACY1SDTF;
TRTSTMF=ACY1STMF;
run;

proc sql;
create table source.ADSL31 as
select AD30.*, EPOCHnummax as TRTCYCmax
from source.ADSL30 as AD30
left join
source.ADSLEX7a as AD7a
on AD30.USUBJID=AD7a.USUBJID;
quit;

proc sql noprint;
select New_Variable into:fmtlist4 separated by " "
from source.ADSL28
where join="EDTM" and CYCNUM<20 and CYCNUM>0;
quit;

proc sql noprint;
select New_Variable into:fmtlist5 separated by " "
from source.ADSL28
where join="EDTF" and CYCNUM<20 and CYCNUM>0;
quit;

proc sql noprint;
select New_Variable into:fmtlist6 separated by " "
from source.ADSL28
where join="ENMF" and CYCNUM<20 and CYCNUM>0;
quit;

data source.ADSL32(drop=i TRTCYCmax);
set source.ADSL31;
ARRAY EDTM [19] &fmtlist4;
ARRAY EDTF [19] $ &fmtlist5;
ARRAY ENMF [19] $ &fmtlist6;
do i=1 to 19;
if i= TRTCYCmax then do;
              	TRTENDTM=EDTM[i];
				TRTEDTF=EDTF[i];
				TRTETMF=ENMF[i];
				end;
end;
format TRTSTDTM TRTENDTM datetime16.;
run;

data source.ADSL33(drop=DOMAIN AGEC);
merge source.ADSL4 source.ADSL32;
by USUBJID;
if REGION1="Eastern Europe" then REGION1N=1;
if REGION1="Western Europe" then REGION1N=2;
if REGION1="North America" then REGION1N=3;
if REGION1="Other" then REGION1N=4;
if AGEC=">=84" then AGEGR1=AGEC;else AGEGR1="<84";
if AGEGR1=">=84" then AGEGR1N=1;
if AGEGR1="<84" then AGEGR1N=2;
if RANDFL="Y" and ACTARM in ("PLACEBO","4MG AFLIBERCEPT") then EXPFL="Y"; else EXPFL="N";
run;

/*For Evaluable Patient Population Flag EPPFL the following criteria are to be checked:

Evaluable Patient (EP) population for tumor response will consist of all randomized and treated
patients, with cytologically or histologically confirmed pancreatic cancer, with metastatic and
measurable disease at study entry, in first line setting and evaluable for response (i.e. patients with
at least one tumoral evaluation while on treatment, except for early disease progression/cancerrelated
death).

Here it is assumed that in-first-line treatment includes all patients excluding those from
from PR Domain who received prior ANTI-CANCER Therapy.*/

data source.ADSL34a(keep=RUSUBJID);
set original.cd;
if CDTESTCD="EXTENT" and CDSTRESC="METASTATIC";
run;

proc sql;
create table source.ADSL34b as
select AD34a.RUSUBJID as USUBJID, AD33.SAFFL
from source.ADSL34a as AD34a, source.ADSL33 as AD33
where AD34a.RUSUBJID=AD33.USUBJID and AD33.SAFFL="Y";
quit;

proc sql;
create table source.ADSL34c as
select distinct USUBJID, TRLNKID,VISITNUM
from target.tr as TR
where TRGRPID = "TARGET";
quit;

proc sql;
create table source.ADSL34d as
select distinct USUBJID
from source.ADSL34c
where VISITNUM=0;
quit;

proc sql;
create table source.ADSL34e as
select USUBJID, TRLNKID, count(TRLNKID) as COUNT
from source.ADSL34c as AD34c
group by USUBJID, TRLNKID
having count(TRLNKID)>1;
quit;

proc sql;
create table source.ADSL34f as
select distinct USUBJID
from source.ADSL34e;
quit;

proc sql;
create table source.ADSL34g as
select distinct USUBJID
from target.PR;
quit;

proc sql;
create table source.ADSL34h as
select USUBJID from source.ADSL34f as AD34f
intersect 
select USUBJID from source.ADSL34c as AD34c
intersect
select USUBJID from source.ADSL34b as AD34b
except
select USUBJID from source.ADSL34g as AD34g;
quit;

proc sql;
create table source.ADSL34i as
select AD33.*, (case when AD33.USUBJID=AD34h.USUBJID then "Y" else "N" end) as EPPFL
from source.ADSL33 as AD33
left join
source.ADSL34h as AD34h
on AD33.USUBJID=AD34h.USUBJID;
quit;

/*For Clinical Benefit we shall use the original.CM At the time of SDTM creation, the ADAM requirements were not taken
into account and rows were compacted without taking into account CMDOSU. Here FACM needs to be created perhaps.
. Hence there is an issue with regards to key variables and CMDOSU is required for clinical benefit analysis.
Same as Original.cd needs to be taken into account with regards to SDTM creation in either the DM domain or a separate
domain. This shall be taken into account during future SDTM creations. For now, original.CM shall be used
Morphine equivalents are as provided in protocol, ECOG PS, pain severity and weight change from baseline are considered
The clinical benefit
population will include randomized patients, with baseline clinical benefit available, with a
minimum pain score ≥ 20 and a minimum analgesic consumption ≥ 10. Factor of 0.05 or 0.005 considered here where not available.
*/

data source.ADSL35(keep=USUBJID CMDECOD CMDOSE);
set original.CM;
USUBJID=RUSUBJID;
if CMSCAT="ANALGESIC";
if VISITNUM=0;
if CMSTDY>=-8 and CMSTDY<=1;
run;

proc import datafile="D:\Pancrea_SanofiU_2007_134\ADAM Submission\Excel Files\MorphineEquivalent.csv" 
out=source.MorphineEquivalent dbms=csv replace; 
getnames=Yes; 
gurssingrows=max;
run;

proc sql;
create table source.ADSL36 as
select AD35.*,MEQ.Morphine_Factor
from source.ADSL35 as AD35
left join
source.MorphineEquivalent as MEQ
on AD35.CMDECOD=upcase(MEQ.CMDECOD);
quit;

data source.ADSl36;
set source.ADSL36;
if Morphine_factor=. then Morphine_factor=0.005;
run;

proc sql;
create table source.ADSL36a as
select USUBJID, sum(CMDOSE*Morphine_Factor) as MEQ
from source.ADSL36 as AD36
group by USUBJID
having sum(CMDOSE*Morphine_Factor)>=10;
quit;

data source.ADSL37;
set target.VS;
where (VISITNUM=0 and VSTESTCD="WEIGHT" and VSSTRESN ne .) or (VISITNUM=0 and VSTESTCD="ECOG" and VSSTRESN ne .);
run;

proc sql;
create table source.ADSL37a as
select distinct USUBJID
from source.ADSL37;
quit;

proc sql;
create table source.ADSL38 as
select distinct USUBJID
from target.QS as QS
group by USUBJID,VISITNUM
having VISITNUM=0 and min(QSSTRESN)>=20;
quit;

proc sql;
create table source.ADSL39 as
select USUBJID from source.ADSL38
intersect
select USUBJID from source.ADSL37a
intersect
select USUBJID from source.ADSL36a;
quit;

proc sql;
create table source.ADSL40 as
select AD34i.*, (case when AD34i.USUBJID=AD39.USUBJID and RANDFL="Y" then "Y" else "N" end) as CBFL
from source.ADSL34i as AD34i
left join
source.ADSL39 as AD39
on AD34i.USUBJID=AD39.USUBJID;
quit;

/*Since the cutoff date is not known, the Last Alive date will be used in the calculation of study endpoints
For the cases where Death Date is available, Last alive is 1 day prior to death date, just one second prior to end of day. 
When death date not available, then last day of contact availabe is converted to datetime*/

proc sql noprint;
select New_Variable into:fmtlist7 separated by ","
from source.ADSL28
where join="EDTM";
quit;

proc sql noprint;
select New_Variable into:fmtlist8 separated by ","
from source.ADSL28
where join="SDTM" and CYCNUM = 1;
quit;

proc sql noprint;
select New_Variable into:fmtlist9 separated by ","
from source.ADSL28
where join="EDTM" and CYCNUM<20;
quit;

data source.ADSL41(drop=lastdosedtm firstdosedtm );
set source.ADSL40;
LSALVDTM=DTHDTM-1;
if LSALVDTM=. then LSALVDTM=max(&fmtlist7);
LSALVDTF="Y";
LSALVTMF="H";
firstdosedtm=&fmtlist8;
lastdosedtm=max(&fmtlist9);
TRTDURD=datepart(lastdosedtm)-datepart(firstdosedtm)+1;
TRTSDTM=firstdosedtm;
TRTEDTM=lastdosedtm;
format LSALVDTM datetime16.;
run;

/*For DTHCAUS in case there is both adverse event in AE domain and Progressive Disease in DS Domain provided.
Progressive Disease in DS domain is considered. Essentially SS domain is copied*/

proc sql;
create table source.ADSL42 as
select AD41.*, SS.SSCAT as DTHCAUS, (case when SS.SSCAT="PROGRESSIVE DISEASE" then 1
                                          when SS.SSCAT="ADVERSE EVENT" then 2
                                          else 3 end) as DTHCAUSN										
from source.ADSL41 as AD41
left join
Target.SS as SS
on AD41.USUBJID=SS.USUBJID and AD41.DTHFL="Y" and SS.SSCAT ne "";
quit;

proc sql;
create table source.ADSL43 as
select AD42.*, ECOG, (case when Strat.SGDECOD="Pancreatectomy" then "Yes" else "No" end) as Pancreatectomy, Strat.Region as Region
from source.ADSL42 as AD42
left join
source.strat as Strat
on AD42.USUBJID=Strat.USUBJID;
quit;

data source.ADSL44(drop=ECOG Pancreatectomy Region);
set source.ADSL43;
STRATAR=compbl(ECOG||","||Pancreatectomy||","||Region);
select;
when (ECOG=0 and Pancreatectomy="No" and Region="Eastern Europe") STRATARN=1;
when (ECOG=0 and Pancreatectomy="No" and Region="Western Europe") STRATARN=2;
when (ECOG=0 and Pancreatectomy="No" and Region="North America") STRATARN=3;
when (ECOG=0 and Pancreatectomy="No" and Region="Other") STRATARN=4;
when (ECOG=0 and Pancreatectomy="Yes" and Region="Eastern Europe") STRATARN=5;
when (ECOG=0 and Pancreatectomy="Yes" and Region="Western Europe") STRATARN=6;
when (ECOG=0 and Pancreatectomy="Yes" and Region="North America") STRATARN=7;
when (ECOG=0 and Pancreatectomy="Yes" and Region="Other") STRATARN=8;

when (ECOG=1 and Pancreatectomy="No" and Region="Eastern Europe") STRATARN=9;
when (ECOG=1 and Pancreatectomy="No" and Region="Western Europe") STRATARN=10;
when (ECOG=1 and Pancreatectomy="No" and Region="North America") STRATARN=11;
when (ECOG=1 and Pancreatectomy="No" and Region="Other") STRATARN=12;
when (ECOG=1 and Pancreatectomy="Yes" and Region="Eastern Europe") STRATARN=13;
when (ECOG=1 and Pancreatectomy="Yes" and Region="Western Europe") STRATARN=14;
when (ECOG=1 and Pancreatectomy="Yes" and Region="North America") STRATARN=15;
when (ECOG=1 and Pancreatectomy="Yes" and Region="Other") STRATARN=16;

when (ECOG=2 and Pancreatectomy="No" and Region="Eastern Europe") STRATARN=17;
when (ECOG=2 and Pancreatectomy="No" and Region="Western Europe") STRATARN=18;
when (ECOG=2 and Pancreatectomy="No" and Region="North America") STRATARN=19;
when (ECOG=2 and Pancreatectomy="No" and Region="Other") STRATARN=20;
when (ECOG=2 and Pancreatectomy="Yes" and Region="Eastern Europe") STRATARN=21;
when (ECOG=2 and Pancreatectomy="Yes" and Region="Western Europe") STRATARN=22;
when (ECOG=2 and Pancreatectomy="Yes" and Region="North America") STRATARN=23;
when (ECOG=2 and Pancreatectomy="Yes" and Region="Other") STRATARN=24;

end;

STRAT1D="Eastern Oncology Group Performance Status";
STRAT1R=ECOG;

STRAT2D="Prior Curative Surgical Therapy";
STRAT2R=Pancreatectomy;
if Pancreatectomy="No" then STRAT2RN=0; else STRAT2RN=1;

STRAT3D="Prior Curative Surgical Therapy";
STRAT3R=Region;
select;
when (Region="Eastern Europe")  STRAT3RN=1;
when (Region="Western Europe")  STRAT3RN=2;
when (Region="North America")  STRAT3RN=3;
when (Region="Other") STRAT3RN=4;
end;

run;
proc transpose data = source.ADSLEX25(obs=0) out=source.ADSL45a;
var _all_;
run;

proc sql noprint;
select _NAME_  into: list21 separated by ","
from source.ADSL45a
where _NAME_ ne "USUBJID";
quit;

proc transpose data = source.ADSL11(obs=0) out=source.ADSL45b;
var _all_;
run;

proc sql noprint;
select _NAME_  into: list22 separated by ","
from source.ADSL45b
where _NAME_ ne "USUBJID";
quit;

proc transpose data = source.ADSLEX43d(obs=0) out=source.ADSL45c;
var _all_;
run;

proc sql noprint;
select _NAME_  into: list23 separated by ","
from source.ADSL45c
where _NAME_ ne "USUBJID";
quit;

proc sql;
create table source.ADSL46 as
select AD44.*, &list21       
from source.ADSL44 as AD44
left join
source.ADSLEX25 as AD25
on AD44.USUBJID=AD25.USUBJID;
quit;
        
proc sql;
create table source.ADSL47 as
select AD46.*, &list22      
from source.ADSL46 as AD46
left join
source.ADSL11 as AD11
on AD46.USUBJID=AD11.USUBJID;
quit;

proc sql;
create table source.ADSL48 as
select AD47.*, &list23      
from source.ADSL47 as AD47
left join
source.ADSLEX43d as AD43d
on AD47.USUBJID=AD43d.USUBJID;
quit;

proc transpose data = source.ADSL48(obs=0) out=source.ADSL48a;
var _all_;
run;

proc sql;
create table source.ADSL49 as
select _NAME_ from source.ADSL1
except 
select _NAME_ from source.ADSL48a;
quit;

data source.ADSL50;
format &list;
set source.ADSL48;
run;

libname target "D:\Pancrea_SanofiU_2007_134\ADAM Submission\SAS Programs";

data target.ADSL;
set source.ADSL50;
run;

/*Impute missing values for EXDOSE*/
/*
data inf_consent(keep = studyid usubjid rficdt); set sdtm.ds; by studyid usubjid; if upcase((scan(dsscat,1," "))) = "PROTOCOL" and upcase(dscat) = "PROTOCOL MILESTONE" and upcase(dsdecod) = "INFORMED CONSENT OBTAINED";
if missing(dsstdtc) then put "WARN" "ING: Missing date of Inform Consent in DS. Please check USUBJID = " USUBJID ;
else if length(dsstdtc) < 10 then put "WARN" "ING: Date of Inform Consent is partial. Please check USUBJID = " USUBJID;
else rficdt = input(dsstdtc,is8601da.); run;


data adsl; merge dm (in = indm) inf_consent (in = incons); by studyid usubjid;
if ^indm or ^incons then put "USER WAR" "NING: Please check number of patients!";
if missing(rficdtc) then put "WARN" "ING: Missing date of Inform Consent in DM. Please check USUBJID = " USUBJID ;
else if length(rficdtc) < 10 then put "WARN" "ING: Date of Inform Consent is partial. Please check USUBJID = " USUBJID;
else if rficdt ^= input(rficdtc, is8601da.) then put "USER WAR" "NING: Inform Consent Date variables from ADSL and DM are inconsistent. Please check USUBJID = " USUBJID; run;

data randomiz;
set sdtm.ds;
by studyid usubjid;
if upcase(dsdecod) = “RANDOMIZATION”;
*/

/*in case of improper coding please check exact value of DSDECOD*/

/*
if missing(dsstdtc) then
put "WARN" "ING: Has the subject" USUBJID = "been randomized? Please check!";
else if length(dsstdtc)<10 then put "WARN" "ING: Date of Randomization is partial. Please check";
else rficdt = input(dsstdtc,is8601da.);
run;

*/

/*
*NOTE: Be sure that all three variables are available in SDTM.AE! Please check using CHECK_EXIST macros;
data ae_death;
set sdtm.ae; if aeout = "FATAL" or aesdth = "Y" or ^missing(aedthdtc);
if cmiss(aeout,aesdth,aedthdtc) < 3 then put "WARN" "ING: Death-related variables in SDTM.AE are inconsistent. Please check!";
run;
	   */
/*

/*
proc transpose data=source.ADSLEX36(obs=0) out=source.ADSLEX37;
var _ALL_;
run;

data source.ADSLEX37a;
set source.ADSLEX37;
if index(_NAME_,'ACY')>0 and index(_NAME_,'SDTM')>0 then do;
newname1=compress('ACY'||input(compress(_NAME_,,"as"),2.)||'EDTM');
newlabel1=compbl("'Cycle "||input(compress(_NAME_,,"as"),2.)||" End Datetime'");
newname2=compress('ACY'||input(compress(_NAME_,,"as"),2.)||'EDTF');
newlabel2=compbl("'Cycle "||input(compress(_NAME_,,"as"),2.)||" Start Date Imputation Flag'");
newname3=compress('ACY'||input(compress(_NAME_,,"as"),2.)||'ETMF');
newlabel3=compbl("'Cycle "||input(compress(_NAME_,,"as"),2.)||" Start Time Imputation Flag'");
output source.ADSLEX37a;
end;
if index(_NAME_,'ACY')>0 and index(_NAME_,'SDM')>0 then do;
newname1=compress('ACY'||input(compress(_NAME_,,"as"),2.)||'EDM');
newlabel1=compbl("'Cycle "||input(compress(_NAME_,,"as"),2.)||" End Datetime'");
newname2=compress('ACY'||input(compress(_NAME_,,"as"),2.)||'EDF');
newlabel2=compbl("'Cycle "||input(compress(_NAME_,,"as"),2.)||" Start Date Imputation Flag'");
newname3=compress('ACY'||input(compress(_NAME_,,"as"),2.)||'EMF');
newlabel3=compbl("'Cycle "||input(compress(_NAME_,,"as"),2.)||" Start Time Imputation Flag'");
output source.ADSLEX37a;
end;
run;


proc sql noprint;
select _NAME_ into:SDTM_list separated by " "
from source.ADSLEX37a;
quit; */
/*
proc sql noprint;
select _NAME_||"="||newname1 into:EDTM_list separated by " "
from source.ADSLEX37a;
quit; 

proc sql noprint;
select compbl(newname1||"="||newlabel1) into:EDTM_Label separated by " "
from source.ADSLEX37a;
quit; 

proc sql noprint;
select _NAME_||"="||newname1 into:EDTM_list separated by " "
from source.ADSLEX37a;
quit; 


proc sql noprint;
select compress(newname1||"="||newname1||"-1;") into:EDTM_val separated by " "
from source.ADSLEX37a;
quit; 

proc sql noprint;
select _NAME_||"="||newname2 into:EDTF_list separated by " "
from source.ADSLEX37a;
quit;


proc sql noprint;
select _NAME_||"="||newname3 into:ETMF_list separated by " "
from source.ADSLEX37a;
quit;
*/


/*
data _null_;*/
/*%put &sdtm_list;
%put &EDTM_list;
%put &EDTF_list;
%put &ETMF_list;

%put &EDTM_Label;*/
/*%put &EDTM_Val;
run;*/

/*

data source.ADSLEX37b(keep=&SDTM_list);
set source.ADSLEX36;
format &SDTM_List datetime16.;
run;

data source.ADSLEX37c;
  obs1 = 1;
  do while( obs1 <= nobs);
    set source.ADSLEX37b nobs=nobs;
    obs2 = obs1 + 1;
    set
      source.ADSLEX37b(rename=(&EDTM_list)) point=obs2;
	  label &EDTM_Label;
    output;
    obs1 + 1;
  end;
run;

options symbolgen;
data source.ADSLEX37d;
set source.ADSLEX37c;
&EDTM_Val;
run;*/
