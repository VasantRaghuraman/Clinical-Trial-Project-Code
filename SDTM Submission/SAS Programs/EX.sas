/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: EX
Programmers: Vasant Raghuraman
Date: April 6, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.EX
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_EX Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=EX)

/*Capturing data from suplied source dataset. EXTERM is assumed to be EXDECOD as it was redacted*/

data source.EX1(drop=ECSEQ ECTRT ECOCCUR ECDOSE ECDOSU ECDOSFRM ECSTDTC ECENDTC ECSTDY ECENDY ECDUR ECTPT ECTPTNUM);
format STUDYID DOMAIN USUBJID EXSEQ EXTRT EXDOSE EXDOSU EXDOSFRM EPOCH EXSTDTC EXENDTC EXSTDY EXENDY EXDUR EXTPT EXTPTNUM;
set target.EC;
DOMAIN = "EX";
EXSEQ=ECSEQ;
EXTRT=ECTRT;
EXDOSE=ECDOSE;
EXDOSU=ECDOSU;
EXDOSFRM=ECDOSFRM;
EXSTDTC=ECSTDTC;
EXENDTC=ECENDTC;
EXSTDY=ECSTDY;
EXENDY=ECENDY;
EXDUR=ECDUR;
EXTPT=ECTPT;
EXTPTNUM=ECTPTNUM;
if ECOCCUR ne "N";
run;

/*Randomization Schedule. Stratification was to be done according to ECOG PS (0 vs 1 vs 2), to prior curative surgery (pancreatectomy, yes vs no) and to
geographical region. Since there is no data regarding ECOG PS, that is omitted in the stratification.*/


/* Combine Original.DM and Original.SG to get the geographical region and prior pancreatectomy*/
data source.SGstrat(keep=USUBJID SGDECOD);
set ORIGINAL.SG;
USUBJID=RUSUBJID;
if SGDECOD="Pancreatectomy";
run;

proc sort data=source.SGstrat nodupkey;
by USUBJID;
run;

proc sql;
create table source.Strat1 as
select DM.RUSUBJID as USUBJID, DM.REGION, SG1.SGDECOD       
from Original.DM as DM
left join
source.SGstrat as SG1
on DM.RUSUBJID=SG1.USUBJID
order by 2,3;
quit;

data source.Strat2;
set source.Strat1;
if SGDECOD ne "Pancreatectomy" then SGDECOD="Not Pancreatectomy";
run;

data source.VSstrat(keep=RUSUBJID VSTESTCD VSORRES);
set original.VS;
if VSTESTCD="ECOG" and VISITNUM=0;
run;

proc sql;
create table source.Strat3 as
select ST2.USUBJID,ST2.REGION,ST2.SGDECOD,(select VSST.VSORRES from source.VSstrat as VSST where ST2.USUBJID=VSST.RUSUBJID)as ECOG
from source.Strat2 as ST2
order by 2,3,4;
quit;

proc surveyselect data=source.Strat3 out=source.Strat4 OUTALL METHOD=SRS samprate=0.5 SEED=123;
strata REGION SGDECOD ECOG;
run;

proc sort data=source.Strat4 out=source.Strat5(drop= SelectionProb SamplingWeight);
by USUBJID;
run;

data source.Strat;
set source.Strat5;
if Selected=1 then do;
ARMCD="4MG AFLIBERCEPT";
ARM="4MG AFLIBERCEPT";
ACTARMCD="4MG AFLIBERCEPT";
ACTARM="4MG AFLIBERCEPT";
end;
else do;
ACTARMCD="PLACEBO";
ACTARM="PLACEBO";
ARMCD="PLACEBO";
ARM="PLACEBO";
end;
run;

/*Link the data from EX1 table to the stratified SRS from DM and SG tables to get USUBJID assigned to treatment and 
placebo groups*/
proc sql;
create table source.EX2 as
select EX1.STUDYID, EX1.DOMAIN, EX1.USUBJID, EX1.EXSEQ, EX1.EXTRT, EX1.EXDOSE, EX1.EXDOSU, EX1.EXDOSFRM, 
       EX1.EPOCH, EX1.EXSTDTC, EX1.EXENDTC, EX1.EXSTDY, EX1.EXENDY, EX1.EXDUR, EX1.EXTPT, EX1.EXTPTNUM, 
	   (select strat.SELECTED from source.Strat5 as strat where EX1.USUBJID=strat.USUBJID) as SELECTED
from source.EX1 as EX1
order by USUBJID;
quit;

/*Since EC visits are as per protocol and there are no unplanned visits, the original VISITNUM is retained.
For Placebo, EXDOSE=0*/
data source.EX2(drop=SELECTED);
set source.EX2;
if SELECTED=1 and EXTRT= "AFLIBERCEPT/PLACEBO" then EXTRT="4MG AFLIBERCEPT";
if SELECTED=0 and EXTRT= "AFLIBERCEPT/PLACEBO" then EXTRT="PLACEBO";
if EXTRT="PLACEBO" then EXDOSE=0;
run;

/*Remove observations for which date was incorrect and sent to data management*/
proc sql;
create table source.EX2A as
select * from source.EX2 as EX2
where not exists 
(select * from source.CMPR2B as CMPR2B 
        where EX2.USUBJID=CMPR2B.RUSUBJID and EX2.EPOCH=CMPR2B.VISIT and 
		      EX2.EXSTDY=CMPR2B.EXSTDY and EX2.DOMAIN = CMPR2B.OBSREMOVE);
quit;

/*Since the unit of collection (mg) is different from the protocol specification (mg/kg), weight from
Original.VS domain is used as an input to calculate (mg/kg)*/

proc sql;
create table source.EX3 as
select EX2A.STUDYID, EX2A.DOMAIN, EX2A.USUBJID, EX2A.EXSEQ, EX2A.EXTRT, EX2A.EXDOSE, EX2A.EXDOSU, EX2A.EXDOSFRM, 
       EX2A.EPOCH, EX2A.EXSTDTC, EX2A.EXENDTC, EX2A.EXSTDY, EX2A.EXENDY, EX2A.EXDUR, EX2A.EXTPT, EX2A.EXTPTNUM, 
(select max(VSORRES) from original.VS as VS where vs.RUSUBJID = EX2A.USUBJID and vs.VSTESTCD="WEIGHT") as WEIGHT
from source.EX2A as EX2A
order by 1,2,3,4;
quit;

data source.EX4(drop=weight);
format STUDYID DOMAIN USUBJID EXSEQ EXTRT EXDOSE EXDOSU EXDOSFRM EPOCH EXSTDTC EXENDTC EXSTDY EXENDY EXDUR EXTPT EXTPTNUM;
set source.EX3;
if upcase(EXTRT)="4MG AFLIBERCEPT" or upcase (EXTRT)="PLACEBO" then do;
EXDOSE=EXDOSE/WEIGHT;
EXDOSE =put(EXDOSE,8.2);
EXDOSU="mg/kg";
EXDOSU=put(EXDOSU,$UNIT.);
end;
else do;
EXDOSE =put(EXDOSE,8.2);
EXDOSU="mg/m2";
EXDOSU=put(EXDOSU,$UNIT.);
end;
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.EX;
set Empty_EX source.EX4;
run;

**** SORT EX ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=EX) 

proc sort data=target.EX; 
by &EXSORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.EX file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\EX.xpt" ; 
run;

proc cport data=target.SUPPEX file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPEX.xpt" ; 
run;



/*From this we can get RFSTDTC RFENDTC*/
data DMEX1(keep=USUBJID EXSTDTM EXSTDT EXENDTM EXENDT EPOCHNUM EXTRT);
set target.EX;
%dtc2dt(EXSTDTC,prefix=EXST);
%dtc2dt(EXENDTC,prefix=EXEN);
EPOCHNUM=input(compress(EPOCH,,"as"),8.);
run;

proc sql;
create table DMEX2 as
select USUBJID, min(EPOCHNUM) as MINEPOCHNUM, max(EPOCHNUM) as MAXEPOCHNUM, EXTRT, EXSTDTM, EXSTDT, EXENDTM, EXENDT, EPOCHNUM  
from work.DMEX1 as EX
group by USUBJID
order by USUBJID, EPOCHNUM;
quit;

proc sql;
create table DMEX3 as
select EX2.USUBJID, EX2.EPOCHNUM,
       min(EX2.EXSTDTM) as RFSTDTM,
       min(EX2.EXSTDT) as RFSTDT,
       max(EX2.EXENDTM)as RFENDTM, 
       max(EX2.EXENDT) as RFENDT
from DMEX2 as EX2
where EPOCHNUM=MINEPOCHNUM
group by USUBJID,EPOCHNUM;
quit;

data source.RFSTDTfin;
length RFSTDTC RFENDTC $16;
set DMEX3;
if (RFSTDT < datepart(RFSTDTM) and RFSTDT ne .) or RFSTDTM=. then RFSTDTC=put(RFSTDT,IS8601da.);
else RFSTDTC=put(RFSTDTM,IS8601dt.);
if RFENDT > datepart(RFENDTM) or RFENDTM=. then RFENDTC=put(RFENDT,IS8601da.);
else RFENDTC=put(RFENDTM,IS8601dt.);
run;

