%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=SV)

/*Since the evaluation is cyclewise, For all the treatment cycles SV start date is as per the EX domain.
 For the end date of visit we shall consider the maximum protocol planned date which is less than the start date
 of the next cycle as per EX domain.

 For the screening cycle end date shall be highest visit date prior to the first treatment date.

 For the follow up cycles, start and end date shall be the minimum and maximum actual dates as per raw data entry*/

proc sql;
create table source.sv21 as
select USUBJID, input(substr(Epoch,7,2),8.)as VISITNUM, min(EX.EXSTDY) as SVSTDY
from Target.EX as EX 
where EX.EXTRT in("PLACEBO","4MG Aflibercept")
group by USUBJID, VISITNUM
order by USUBJID,VISITNUM;
quit;

data source.SV22 (drop= x y);
format USUBJID VISITNUM SVSTDY SVSTDYnext;
  obs1 = 1; 
  do while( obs1 <= nobs);
    set source.SV21 nobs=nobs;
    obs2 = obs1 + 1; 
    set
      source.SV21(
        rename=(
        USUBJID = x 
        VISITNUM = y  
        SVSTDY = SVSTDYnext
        )
      ) point=obs2;
	  label x="USUBJIDnext" y="VISITNUMnext" SVSTDYnext="SVSTDYnext";
	  if USUBJID ne x then	do;
      SVSTDYnext = . ;
	  DosingVisitmax=VISITNUM;
	  end;
	  else DOSINGVISITmax=.;
	  output;
    obs1 + 1; 
  end; 
  drop obs1 obs2;
run;



/* Creating Dataset to compare and test dates for errors and to create SVSTDTC and SVENDTC*/
proc sql;
create table source.cmpr1 as
select rusubjid as USUBJID, visitnum, visit, cestdy
from original.ce
outer union corr
select rusubjid as USUBJID, visitnum, visit, dsstdy, dssthwk
from original.ds
outer union corr
select rusubjid as USUBJID, visitnum, visit, egdy
from original.eg
outer union corr
select rusubjid as USUBJID, visitnum, visit, exstdy, exendy
from original.ex
outer union corr
select rusubjid as USUBJID, visitnum, visit, lbdy, lbendy
from original.lb
outer union corr
select rusubjid as USUBJID, visitnum, visit, lsdy
from original.ls
outer union corr
select rusubjid as USUBJID, visitnum, visit, pcdy
from original.pc
outer union corr
select rusubjid as USUBJID, visitnum, visit, pedy
from original.pe
outer union corr
select rusubjid as USUBJID, visitnum, visit, qsdy
from original.qs
outer union corr
select rusubjid as USUBJID, visitnum, visit, vsdy
from original.vs
order by usubjid, visitnum, visit, dsstdy, dssthwk;
quit;

data source.cmpr2(drop=dssthwk);
set source.cmpr1;
if dsstdy=. then dsstdy=dssthwk*7;
run;

data source.cmpr2a;
set source.cmpr2;
if cestdy =. and dsstdy=. and egdy=. and exstdy=. and exendy=. and lbdy=. and lbendy=. and lsdy=. and pcdy=. and pedy=. and
   qsdy=. and vsdy=. and dsstdy=. then delete;
SVSTDYint=min(cestdy,dsstdy,egdy, exstdy,exendy,lbdy,lbendy,lsdy,pcdy,pedy,qsdy,vsdy,dsstdy);
SVENDYint=max(cestdy,dsstdy,egdy, exstdy,exendy,lbdy,lbendy,lsdy,pcdy,pedy,qsdy,vsdy,dsstdy);
run;


proc sql;
create table source.cmpr3 as
select USUBJID, VISITNUM, 
min(SVSTDYint) as SVSTDYmin,
max(SVENDYint) as SVENDYmax
from source.cmpr2a as cmpr2a
group by USUBJID, VISITNUM
order by USUBJID, VISITNUM;
quit;

proc sql;
create table source.Sv23 as 
select cmpr3.USUBJID, cmpr3.VISITNUM, cmpr3.SVSTDYmin as SVSTDYcmpltmin, cmpr3.SVENDYmax as SVENDYcmpltmax,
       sv22.SVSTDY, sv22.SVSTDYnext,sv22.DosingVISITmax
from source.CMPR3 as cmpr3
left join
source.sv22 as sv22
on cmpr3.USUBJID=sv22.USUBJID and cmpr3.VISITNUM=sv22.VISITNUM;
quit;

data source.sv24(drop=SVSTDYnext SVSTDYcmpltmin SVENDYcmpltmax DOSINGVISITmax);
set source.sv23;
if SVSTDY=. then SVSTDY=SVSTDYcmpltmin;
SVENDY=SVENDYcmpltmax;
if VISITNUM=99 then delete;
run;

data source.sv25;
format USUBJID VISITNUM SVSTDY SVENDY SVSTDYnext SVENDYnext;
  obs1 = 1; 
  do while( obs1 <= nobs);
    set source.SV24 nobs=nobs;
    obs2 = obs1 + 1; 
    set
      source.SV24(
        rename=(
        USUBJID = USUBJIDnext
        VISITNUM = VISITNUMnext  
        SVSTDY = SVSTDYnext
		SVENDY = SVENDYnext
        )
      ) point=obs2;
	  label USUBJIDnext="USUBJIDnext" VISITNUMnext="VISITNUMnext" SVSTDYnext="SVSTDYnext" SVENDYnext="SVENDYnext";
	  if obs1 >1 then do;
	  obs3=obs1-1;
      set
      source.SV24(
        rename=(
        USUBJID = USUBJIDprev
        VISITNUM = VISITNUMprev  
        SVSTDY = SVSTDYprev
		SVENDY = SVENDYprev
        )
      ) point=obs3;
	  end;
	  output;
    obs1 + 1; 
  end; 
  drop obs1 obs2 obs3;
run;

data source.SV25a source.SV25b source.SV25C;
set source.SV25;
if USUBJID=USUBJIDprev and SVSTDY<=SVENDYprev then do;
output source.SV25a;
end;
if USUBJID=USUBJIDnext and SVENDY<SVSTDY then output source.sv25b;
if USUBJID=USUBJIDnext and SVENDY>SVSTDYnext then output source.SV25C;
run;

proc sql;
create table source.sv25a1 as 
select sv25a.USUBJID, sv25a.VISITNUM,sv25a.SVSTDY, sv25a.SVENDY, sv25a.SVSTDYprev, sv25a.SVENDYprev,cmpr2a.SVSTDYint
from source.cmpr2a as cmpr2a, source.sv25a as sv25a
where sv25a.USUBJID=cmpr2a.USUBJID and sv25a.VISITNUM=cmpr2a.VISITNUM
order by 1,2;
quit;

data source.sv25a11;
set source.sv25a1;
if SVSTDYint>SVSTDYprev and SVSTDYint>SVENDYprev;
run;

proc sql;
create table source.sv25a2 as
select sv25a11.USUBJID, SV25a11.VISITNUM, min(SVSTDYint) as SVSTDYnew label="UPdated SVSTDY"
from source.sv25a11 as sv25a11
group by 1,2
order by 1,2;
quit;

proc sql;
 create table source.sv25a3 as
 select sv24.USUBJID, sv24.VISITNUM, max(sv24.SVSTDY,sv25a2.SVSTDYnew) as SVSTDY, sv24.SVENDY
 from source.sv24 as sv24
 left join
 source.sv25a2 as sv25a2
 on sv24.USUBJID=sv25a2.USUBJID and sv24.VISITNUM=sv25a2.VISITNUM;
 quit;

data source.SV26 (drop= x y);
format USUBJID VISITNUM SVSTDY SVENDY SVSTDYnext SVENDYnext USUBJIDnext VISITNUMnext;
  obs1 = 1; 
  do while( obs1 <= nobs);
    set source.SV25a3 nobs=nobs;
    obs2 = obs1 + 1; 
    set
      source.SV25a3(
        rename=(
        USUBJID = USUBJIDnext 
        VISITNUM = VISITNUMnext 
        SVSTDY = SVSTDYnext
		SVENDY=SVENDYnext
        )
      ) point=obs2;
	  label USUBJIDnext="USUBJIDnext" VISITNUMnext="VISITNUMnext" SVSTDYnext="SVSTDYnext" SVENDYnext="SVENDYnext";
	output;
    obs1 + 1; 
  end; 
  drop obs1 obs2;
run;

proc sql;
create table source.sv26a as 
select sv26.USUBJID, sv26.VISITNUM,sv26.SVSTDY, sv26.SVENDY, sv26.SVSTDYnext, sv26.SVENDYnext,cmpr2a.SVENDYint
from source.cmpr2a as cmpr2a, source.sv26 as sv26
where sv26.USUBJID=cmpr2a.USUBJID and sv26.VISITNUM=cmpr2a.VISITNUM and cmpr2a.SVENDYint<sv26.SVSTDYnext and cmpr2a.SVENDYint<sv26.SVENDYnext
order by 1,2;
quit;

proc sql;
create table source.sv26b as
select USUBJID, VISITNUM, max(SVENDYint) as SVENDYnew label="Updated SVENDY"
from source.sv26a as sv26a
group by 1,2
order by 1,2;
quit;

proc sql;
create table source.sv27 as
select sv25a3.USUBJID, sv25a3.VISITNUM, sv25a3.SVSTDY, min(sv25a3.SVENDY,sv26b.SVENDYnew) as SVENDY
from source.sv25a3 as sv25a3
left join
source.sv26b as sv26b
on sv25a3.USUBJID=sv26b.USUBJID and sv25a3.VISITNUM=sv26b.VISITNUM
order by 1,2;
quit;


data source.sv27d;
format USUBJID VISITNUM SVSTDY SVENDY SVSTDYnext SVENDYnext;
  obs1 = 1; 
  do while( obs1 <= nobs);
    set source.SV27 nobs=nobs;
    obs2 = obs1 + 1; 
    set
      source.SV27(
        rename=(
        USUBJID = USUBJIDnext
        VISITNUM = VISITNUMnext  
        SVSTDY = SVSTDYnext
		SVENDY = SVENDYnext
        )
      ) point=obs2;
	  label USUBJIDnext="USUBJIDnext" VISITNUMnext="VISITNUMnext" SVSTDYnext="SVSTDYnext" SVENDYnext="SVENDYnext";
	  if obs1 >1 then do;
	  obs3=obs1-1;
      set
      source.SV27(
        rename=(
        USUBJID = USUBJIDprev
        VISITNUM = VISITNUMprev  
        SVSTDY = SVSTDYprev
		SVENDY = SVENDYprev
        )
      ) point=obs3;
	  end;
	  output;
    obs1 + 1; 
  end; 
  drop obs1 obs2 obs3;
run;

data source.SV27a source.SV27b source.SV27C;
set source.SV27d;
if USUBJID=USUBJIDprev and SVSTDY<=SVENDYprev then do;
output source.SV27a;
end;
if USUBJID=USUBJIDnext and SVENDY<SVSTDY then output source.sv27b;
if USUBJID=USUBJIDnext and SVENDY>=SVSTDYnext then output source.SV27C;
run;

/**********************************REPEAT TO FIX UNORDERED DATES AGAIN****************************************/

proc sql;
create table source.sv27a1 as 
select sv27a.USUBJID, sv27a.VISITNUM,sv27a.SVSTDY, sv27a.SVENDY, sv27a.SVSTDYprev, sv27a.SVENDYprev,cmpr2a.SVSTDYint
from source.cmpr2a as cmpr2a, source.sv27a as sv27a
where sv27a.USUBJID=cmpr2a.USUBJID and sv27a.VISITNUM=cmpr2a.VISITNUM
order by 1,2;
quit;

data source.sv27a11;
set source.sv27a1;
if SVSTDYint>SVSTDYprev and SVSTDYint>SVENDYprev;
run;

proc sql;
create table source.sv27a2 as
select sv27a11.USUBJID, SV27a11.VISITNUM, min(SVSTDYint) as SVSTDYnew label="UPdated SVSTDY"
from source.sv27a11 as sv27a11
group by 1,2
order by 1,2;
quit;

proc sql;
 create table source.sv27a3 as
 select sv27.USUBJID, sv27.VISITNUM, max(sv27.SVSTDY,sv27a2.SVSTDYnew) as SVSTDY, sv27.SVENDY
 from source.sv27 as sv27
 left join
 source.sv27a2 as sv27a2
 on sv27.USUBJID=sv27a2.USUBJID and sv27.VISITNUM=sv27a2.VISITNUM;
 quit;

data source.SV28 (drop= x y);
format USUBJID VISITNUM SVSTDY SVENDY SVSTDYnext SVENDYnext USUBJIDnext VISITNUMnext;
  obs1 = 1; 
  do while( obs1 <= nobs);
    set source.SV27a3 nobs=nobs;
    obs2 = obs1 + 1; 
    set
      source.SV27a3(
        rename=(
        USUBJID = USUBJIDnext 
        VISITNUM = VISITNUMnext 
        SVSTDY = SVSTDYnext
		SVENDY=SVENDYnext
        )
      ) point=obs2;
	  label USUBJIDnext="USUBJIDnext" VISITNUMnext="VISITNUMnext" SVSTDYnext="SVSTDYnext" SVENDYnext="SVENDYnext";
	output;
    obs1 + 1; 
  end; 
  drop obs1 obs2;
run;

proc sql;
create table source.sv28a as 
select sv28.USUBJID, sv28.VISITNUM,sv28.SVSTDY, sv28.SVENDY, sv28.SVSTDYnext, sv28.SVENDYnext,cmpr2a.SVENDYint
from source.cmpr2a as cmpr2a, source.sv28 as sv28
where sv28.USUBJID=cmpr2a.USUBJID and sv28.VISITNUM=cmpr2a.VISITNUM and cmpr2a.SVENDYint<sv28.SVSTDYnext and cmpr2a.SVENDYint<sv28.SVENDYnext
order by 1,2;
quit;

proc sql;
create table source.sv28b as
select USUBJID, VISITNUM, max(SVENDYint) as SVENDYnew label="Updated SVENDY"
from source.sv28a as sv28a
group by 1,2
order by 1,2;
quit;

proc sql;
create table source.sv29 as
select sv27a3.USUBJID, sv27a3.VISITNUM, sv27a3.SVSTDY, min(sv27a3.SVENDY,sv28b.SVENDYnew) as SVENDY
from source.sv27a3 as sv27a3
left join
source.sv28b as sv28b
on sv27a3.USUBJID=sv28b.USUBJID and sv27a3.VISITNUM=sv28b.VISITNUM
order by 1,2;
quit;


data source.sv29d;
format USUBJID VISITNUM SVSTDY SVENDY SVSTDYnext SVENDYnext;
  obs1 = 1; 
  do while( obs1 <= nobs);
    set source.SV29 nobs=nobs;
    obs2 = obs1 + 1; 
    set
      source.SV29(
        rename=(
        USUBJID = USUBJIDnext
        VISITNUM = VISITNUMnext  
        SVSTDY = SVSTDYnext
		SVENDY = SVENDYnext
        )
      ) point=obs2;
	  label USUBJIDnext="USUBJIDnext" VISITNUMnext="VISITNUMnext" SVSTDYnext="SVSTDYnext" SVENDYnext="SVENDYnext";
	  if obs1 >1 then do;
	  obs3=obs1-1;
      set
      source.SV29(
        rename=(
        USUBJID = USUBJIDprev
        VISITNUM = VISITNUMprev  
        SVSTDY = SVSTDYprev
		SVENDY = SVENDYprev
        )
      ) point=obs3;
	  end;
	  output;
    obs1 + 1; 
  end; 
  drop obs1 obs2 obs3;
if USUBJID=USUBJIDprev and SVSTDY=SVSTDYprev and SVENDY=SVENDYprev then delete;
run;

data source.SV29a source.SV29b source.SV29C;
set source.SV29d;
if USUBJID=USUBJIDprev and SVSTDY<=SVENDYprev then output source.SV29a;
if USUBJID=USUBJIDnext and SVENDY>=SVSTDYnext then output source.SV29C;
if USUBJID=USUBJIDnext and SVENDY<SVSTDY then SVENDY=SVSTDY;
run;


/**********************************REPEAT TO FIX UNORDERED DATES AGAIN****************************************/


proc sql;
create table source.sv29a1 as 
select sv29a.USUBJID, sv29a.VISITNUM,sv29a.SVSTDY, sv29a.SVENDY, sv29a.SVSTDYprev, sv29a.SVENDYprev,
min(max(cestdy,SVENDYprev),max(dsstdy,SVENDYprev),max(egdy,SVENDYprev), 
        max(exstdy,SVENDYprev),max(exendy,SVENDYprev),max(lbdy,SVENDYprev),max(lbendy,SVENDYprev),
        max(lsdy,SVENDYprev),max(pcdy,SVENDYprev),max(pedy,SVENDYprev),max(qsdy,SVENDYprev),max(vsdy,SVENDYprev),
        max(dsstdy,SVENDYprev)) as SVSTDYint
from source.sv29a as sv29a,source.cmpr2a as cmpr2a
where sv29a.USUBJID=cmpr2a.USUBJID and sv29a.VISITNUM=cmpr2a.VISITNUM;
quit;

proc sql;
create table source.sv29a2 as
select sv29a1.USUBJID, SV29a1.VISITNUM, min(SVSTDYint) as SVSTDYnew label="UPdated SVSTDY"
from source.sv29a1 as sv29a1
group by 1,2
order by 1,2;
quit;

proc sql;
 create table source.sv29a3 as
 select sv29.USUBJID, sv29.VISITNUM, max(sv29.SVSTDY,sv29a2.SVSTDYnew) as SVSTDY, sv29.SVENDY
 from source.sv29 as sv29
 left join
 source.sv29a2 as sv29a2
 on sv29.USUBJID=sv29a2.USUBJID and sv29.VISITNUM=sv29a2.VISITNUM;
 quit;

 
data source.sv30;
format USUBJID VISITNUM SVSTDY SVENDY SVSTDYnext SVENDYnext;
  obs1 = 1; 
  do while( obs1 <= nobs);
    set source.SV29a3 nobs=nobs;
    obs2 = obs1 + 1; 
    set
      source.SV29a3(
        rename=(
        USUBJID = USUBJIDnext
        VISITNUM = VISITNUMnext  
        SVSTDY = SVSTDYnext
		SVENDY = SVENDYnext
        )
      ) point=obs2;
	  label USUBJIDnext="USUBJIDnext" VISITNUMnext="VISITNUMnext" SVSTDYnext="SVSTDYnext" SVENDYnext="SVENDYnext";
	  if obs1 >1 then do;
	  obs3=obs1-1;
      set
      source.SV29a3(
        rename=(
        USUBJID = USUBJIDprev
        VISITNUM = VISITNUMprev  
        SVSTDY = SVSTDYprev
		SVENDY = SVENDYprev
        )
      ) point=obs3;
	  end;
	  output;
    obs1 + 1; 
  end; 
  drop obs1 obs2 obs3;
run;

data source.SV30a source.SV30b source.SV30C;
set source.SV30;
if USUBJID=USUBJIDprev and SVSTDY<=SVENDYprev then output source.SV30a;
if USUBJID=USUBJIDnext and SVENDY>=SVSTDYnext then output source.SV30C;
if USUBJID=USUBJIDnext and SVENDY<SVSTDY then SVENDY=SVSTDY;
run;

 
proc sql;
create table source.sv30C1 as 
select sv30c.USUBJID, sv30c.VISITNUM,sv30c.SVSTDY, sv30c.SVENDY, sv30c.SVSTDYnext, sv30c.SVENDYnext,
max(min(cestdy,SVSTDYnext-1),min(dsstdy,SVSTDYnext-1),min(egdy,SVSTDYnext-1), 
        min(exstdy,SVSTDYnext-1),min(exendy,SVSTDYnext-1),min(lbdy,SVSTDYnext-1),min(lbendy,SVSTDYnext-1),
        min(lsdy,SVSTDYnext-1),min(pcdy,SVSTDYnext-1),min(pedy,SVSTDYnext-1),min(qsdy,SVSTDYnext-1),min(vsdy,SVSTDYnext-1),
        min(dsstdy,SVSTDYnext-1)) as SVENDYint
from source.cmpr2a as cmpr2a, source.sv30c as sv30c
where sv30c.USUBJID=cmpr2a.USUBJID and sv30c.VISITNUM=cmpr2a.VISITNUM 
order by 1,2;
quit;

proc sql;
create table source.sv30c2 as
select USUBJID, VISITNUM, max(SVENDYint) as SVENDYnew label="Updated SVENDY"
from source.sv30c1 as sv30c1
group by 1,2
order by 1,2;
quit;

proc sql;
create table source.sv30c3 as
select sv29a3.USUBJID, sv29a3.VISITNUM, sv29a3.SVSTDY, min(sv29a3.SVENDY,sv30c2.SVENDYnew) as SVENDY
from source.sv29a3 as sv29a3
left join
source.sv30c2 as sv30c2
on sv29a3.USUBJID=sv30c2.USUBJID and sv29a3.VISITNUM=sv30c2.VISITNUM
order by 1,2;
quit;

data source.sv31(drop=REASON USUBJIDprev SVSTDYprev SVENDYprev VISITNUMprev USUBJIDnext VISITNUMnext SVSTDYnext SVENDYnext) 
     source.svobsremove(drop=USUBJIDnext VISITNUMnext SVSTDYnext SVENDYnext);
set source.sv30;
if USUBJID=USUBJIDprev and SVSTDY=SVSTDYprev and SVENDY=SVENDYprev then do;
REASON="Start and End dates of Visit are same as previous visit";
output source.svobsremove;
delete;
end;
if SVENDY<SVSTDY then SVENDY=SVSTDY;
output source.sv31;
run;


data source.sv;
format STUDYID DOMAIN USUBJID VISITNUM SVSTDY SVENDY SVUPDES;
set source.sv31;
STUDYID="EFC10547";
DOMAIN="SV";
SVUPDES="";
run;

/************************END OF ITERATION FOR SV DOMAIN PLANNED VISITS*********************************************************/


/*Unplanned events from CE domain*/
proc sql;
create table source.unplanCE as
select  STUDYID, DOMAIN, rusubjid as USUBJID, VISITNUM, VISIT, CESTDY as SVSTDY
from Original.CE
where visitnum=99
order by 1,2,3;
quit;

data source.unplanCE;
format &SVKEEPSTRING;
set source.unplanCE;
SVUPDES="CE";
DOMAIN="SV";
run;

/*Unplanned events from EG domain*/
proc sql;
create table source.unplanEG as
select  STUDYID, DOMAIN, rusubjid as USUBJID, VISITNUM, VISIT, EGDY as SVSTDY
from Original.EG
where visitnum=99
order by 1,2,3;
quit;

data source.unplanEG;
format &SVKEEPSTRING;
set source.unplanEG;
SVUPDES = "EG";
DOMAIN = "SV";
run;

/*Unplanned events from LS domain*/
proc sql;
create table source.unplanLS as
select  STUDYID, DOMAIN, rusubjid as USUBJID, VISITNUM, VISIT, LSDY as SVSTDY, LSTESTCD
from Original.LS
where visitnum=99 and LSTESTCD ne "COMBRES"
order by 1,2,3;
quit;

data source.unplanLS (drop=LSTESTCD);
format &SVKEEPSTRING;
set source.unplanLS;
if LSTESTCD="SYMPDET" then SVUPDES = "RS";
else SVUPDES="TR";
DOMAIN = "SV";
run;

/*Unplanned events from DS domain*/
proc sql;
create table source.unplanDS as
select  STUDYID, DOMAIN, rusubjid as USUBJID, VISITNUM, VISIT, max(DSSTDY,DSSTHWK*7) as SVSTDY
from Original.DS
where visitnum=99
order by 1,2,3;
quit;

data source.unplanDS;
format &SVKEEPSTRING;
set source.unplanDS;
SVUPDES = "DS";
DOMAIN = "SV";
run;

/*All data from unplanned events*/
data source.unplan;
set source.unplanCE source.unplanEG source.unplanLS source.unplanDS;
by STUDYID DOMAIN USUBJID;
RUN;

proc sort data=source.unplan;
by STUDYID DOMAIN USUBJID SVSTDY;
run;

/*For unplanned events that have missing start dates make 999.01 and visit=unscheduled */
data source.unplan1;
set source.unplan;
if svstdy=.;
run;

data source.unplan2;
retain VISITNUM1 &SVKEEPSTRING;
set source.unplan1;
by STUDYID DOMAIN USUBJID SVSTDY;
if first.usubjid=1   then visitnum1=999.01;
else visitnum1=visitnum1+0.01;
run;

data source.unplan3(drop=visitnum1);
set source.unplan2;
	visitnum=visitnum1;
	visit="Unscheduled";
run;

/*Unplanned visits with start dates*/
data source.unplan4;
set source.unplan;
if not(svstdy =.);
run;

/*Combine planned visits and unplanned visits with start dates and sort*/
data source.svcomplt;
format STUDYID DOMAIN USUBJID VISITNUM VISIT SVSTDY SVENDY SVUPDES;
length SVUPDES $10;
set source.sv source.unplan4;
run;

proc sort data=source.svcomplt;
by USUBJID SVSTDY;
run;

/*For unplanned visits with start dates, try to  organize in between visits*/
data source.svcomplt1(drop=prevvisitnum);
retain VISITNUM1 &SVKEEPSTRING;
set source.svcomplt;
prevvisitnum=lag(visitnum);
if (visitnum=99 and prevvisitnum ne 99) then visitnum1=prevvisitnum+0.01;
else if (visitnum=99 and prevvisitnum = 99) then visitnum1=visitnum1+0.01;
else visitnum1=.;
run;

data source.svcomplt2(drop=visitnum1);
set source.svcomplt1;
format visit $40.;
informat visit $40.;
Domain="SV";
if visitnum=99 then do;
visitnum=visitnum1;
visit =compbl("Unscheduled Visit"||put(visitnum1,BEST12.));
end;
else VISIT=compbl("VISIT "||VISITNUM);
if SVENDY=. and SVSTDY ne . then SVENDY=SVSTDY;
run;

/* To test the proper dates we consider day 1 for all subjects as June 30, 2013 which 1s 19539*/


data _null_;
var=put(19539,date9.);
put "The date 19539 is:" var;
run;

data source.svcomplt3(drop=SVSTDT SVENDT);
set source.svcomplt2 source.unplan3;
if SVSTDY ne . then do;
if SVSTDY>0 then SVSTDT=intnx('day',19539,SVSTDY-1);
if SVSTDY<0 then SVSTDT=intnx('day',19539,SVSTDY);
end;
else SVSTDT = .;

if SVENDY ne . then do;
if SVENDY>0 then SVENDT=intnx('day',19539,SVENDY-1);
if SVENDY<0 then SVENDT=intnx('day',19539,SVENDY);
end;
else SVENDT = .;

if SVSTDT ne . then SVSTDTC=put(SVSTDT,IS8601da.);
else SVSTDTC="";

if SVENDT ne . then SVENDTC=put(SVENDT,IS8601da.);
else SVENDTC="";

%dtc2dt(SVSTDTC , prefix=SVSTNEW);
%dtc2dt(SVENDTC , prefix=SVENNEW);
run;

proc sort data=source.svcomplt3;
by USUBJID VISITNUM;
run;

proc sql;
create table test as
select distinct RUSUBJID
from original.EX;
quit;

proc sql;
create table source.svcomplt4 as
select cmplt3.STUDYID, cmplt3.DOMAIN, cmplt3.USUBJID, cmplt3.VISITNUM, cmplt3.VISIT, cmplt3.SVSTDTC, cmplt3.SVENDTC,
       cmplt3.SVSTNEWDT, cmplt3.SVENNEWDT, RFST.RFSTDT, cmplt3.SVUPDES
from source.svcomplt3 as cmplt3
left join
source.RFSTDTFIN as RFST
on cmplt3.USUBJID=RFST.USUBJID
order by USUBJID, VISITNUM;
quit;

data source.svcomplt5(drop=SVSTNEWDT SVENNEWDT RFSTDT);
format STUDYID DOMAIN USUBJID VISITNUM VISIT SVSTDTC SVENDTC SVSTDY SVENDY SVUPDES;
set source.svcomplt4;
if SVSTNEWDT>=RFSTDT then SVSTDY=SVSTNEWDT-RFSTDT+1;
if SVSTNEWDT<RFSTDT then SVSTDY=SVSTNEWDT-RFSTDT;
if SVENNEWDT>=RFSTDT then SVENDY=SVENNEWDT-RFSTDT+1;
if SVENNEWDT<RFSTDT then SVENDY=SVENNEWDT-RFSTDT;
run;

data target.sv;
set Empty_SV source.svcomplt5;
run;

**** SORT SV ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=SV) 

proc sort data=target.sv; 
by &SVSORTSTRING; 
run;
 
/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.SV file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SV.xpt" ; 
run;
