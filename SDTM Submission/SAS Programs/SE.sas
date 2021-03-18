%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=SE)

/* Create SE Dataset from TA, TE, SV, DM and EX Dataset. Randomization done according to stratification factors from STRAT5 in 
EX domain. Normally randomization is provided and strat is calculated here*/

data Source.Strat;
set source.strat5;
if Selected = 1 then do;
ARM = "4MG Aflibercept";
ARMCD = "4MG Aflibercept";
ACTARMCD = "4MG Aflibercept";
ACTARM = "4MG Aflibercept";
end;
else do;
ARM="PLACEBO";
ARMCD = "PLACEBO";
ACTARMCD = "PLACEBO";
ACTARM = "PLACEBO";
end;
run;

data source.se1(drop= SVSTDY SVENDY SVENDTC SVSTDTC SVUPDES SVSTDTM SVENDTM);
set target.SV;
/*if SVSTDY =. then delete;*/
if index(upcase(VISIT),"UNSCHEDULED") > 0  then delete;
%dtc2dt(SVSTDTC , prefix=SVST);
%dtc2dt(SVENDTC , prefix=SVEN);
run;

data source.se2;
   set source.se1 nobs=nobs;
   next1 = _n_ + 1;
   if _n_ < nobs then set source.se1(keep=SVSTDT rename=(SVSTDT=SVSTDYNEXT)) point=next1;
   label SVSTDYNEXT="Subject Visit Next Start Date";
run;

data source.se3(drop=SVENDT SVSTDT SVSTDYNEXT);
set source.se2;
by STUDYID DOMAIN USUBJID;
if first.usubjid then SESEQ=0;
SESEQ+1;
SESTDT=SVSTDT;
SEENDT=SVENDT;
SESTDTNEXT=SVSTDYNEXT;
IF LAST.USUBJID  then SESTDTNEXT=SEENDT;
DOMAIN="SE";
run;

proc sql;
create table source.se4 as
select SE3.STUDYID, se3.DOMAIN, se3.USUBJID, se3.VISITNUM, se3.VISIT, se3.SESTDT, se3.SEENDT, se3.SESTDTNEXT, se3.SESEQ, strat.ACTARMCD
from source.se3 as se3
left join
source.strat as strat
on se3.USUBJID = strat.USUBJID
order by 1,2,3,4;
QUIT;

/* To test the proper dates we consider day 1 for all subjects as June 30, 2013 which 1s 19539*/
data source.se5(drop=visitnum visit SESTDTNEXT SESTDT SEENDT);
set source.se4;
by STUDYID DOMAIN USUBJID;
if VISITNUM<20 then TAETORD=VISITNUM+1;
if VISITNUM>=80 then TAETORD=VISITNUM-58;

if not(last.USUBJID) and not(last.VISITNUM) then SEENDT=SESTDTNEXT-1;

if SESTDT ne . then SESTDTC=put(SESTDT,IS8601da.);
else SESTDTC="";

if SEENDT ne . then SEENDTC=put(SEENDT,IS8601da.);
else SEENDTC="";

label SESTDTC="Subject Element Start Date", SEENDTC="Subject Element End Date";
run;

proc sql;
create table source.se6 as
select se5.STUDYID, se5.DOMAIN, se5.USUBJID, se5.SESEQ, TA.ETCD, TA.ELEMENT, se5.SESTDTC, se5.SEENDTC, se5.TAETORD, TA.EPOCH
from source.se5 as se5
left join
Target.TA as TA
on se5.TAETORD=TA.TAETORD and se5.ACTARMCD=TA.ARMCD
order by 1,2,3,4;
quit;

data target.SE;
set Empty_SE source.se6;
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.SE file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SE.xpt" ; 
run;

