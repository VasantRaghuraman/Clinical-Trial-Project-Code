/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: PC
Programmers: Vasant Raghuraman
Date: May 1, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.PC
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_DS Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=PC)

proc sql;
create table source.PCRF as
select PC.*,RFST.RFSTDT 
from original.PC as PC
left join
source.RFSTDTFIN as RFST
on PC.RUSUBJID=RFST.USUBJID;
quit;


/*Capturing data from suplied source dataset. PCTERM is assumed to be PCDPCOD as it was redacted*/

data source.PC1(drop=RSUBJID RUSUBJID PCTM PCTM PCDT PCDTM RFSTDT);
format STUDYID DOMAIN USUBJID PCSEQ PCREFID PCTESTCD PCTEST PCCAT PCORRES PCORRESU PCSTRESC PCSTRESN PCSTRESU PCSTAT 
       PCNAM PCSPEC PCDRVFL PCLLOQ VISITNUM VISIT PCDTC PCDY PCTPT PCTPTNUM;
set source.PCRF;
USUBJID=RUSUBJID;

/* To test the proper dates we consider day 1 for all subjects as June 30, 2013 which 1s 19539*/

if PCDY ne . then do;
if PCDY>0 then PCDT=RFSTDT+PCDY-1;
if PCDY<0 then PCDT=RFSTDT+PCDY;
end;
else PCDT = .;

/*Here, since PCDY  has label of Day of Specimen Collection, it is used to get PCDTC
PCDY is also assumed to be study day of specimen collection in Analysis dataset and is removed from SDTM
VISITNUM is kept as collected but will need to be derived in analysis dataset  along with PCDY*/
PCDY=.;

if PCDT ne . then do;
	if PCTM ne . then do;
			PCDTM=dhms(PCDT,0,0,PCTM); 
			PCDTC=put(PCDTM,IS8601dt.);
	end;
	else PCDTC=put(PCDT,IS8601da.);
end;
else PCDTC="";

PCORRESU=put(PCORRESU,$UNIT.);
PCSTRESU=put(PCSTRESU,$UNIT.);
PCSPEC=put(PCSPEC,$SPECTYPE.);
VISIT=put(VISITNUM,VISIT.);
run;

/*QC Test 1: Check to see if there are duplicate observations for key variables*/

proc sort data=source.PC1 nodupkey dupout=PC1;
by USUBJID PCTESTCD VISITNUM PCTPTNUM;
run;

data PC1;
set PC1;
Error="Duplicate observations provided for USUBJID PCTESTCD VISITNUM PCTPTNUM as Key Variables";
run;

/*QC Test 2:Check if PCORRES present but PCSTRESC not present. PCSTRESC present but PCORRES not present.
PCSTRESN present but PCSTRESC or PCORRES not present. PCSTRESC is numeric but PCSTRESN not present
PCORRESU present but PCSTRESU not present. PCSTRESU present but PCORRESU not present*/

data PC2 source.PC1;
length Error $100;
set source.PC1;
if PCORRES ne "" and PCSTRESC = "" then do;
Error="Alert: PCORRES present but PCSTRESC not present";
output PC2;
delete;
end;
if PCORRES = "" and PCSTRESC ne "" then do;
Error="Alert: PCSTRESC present but PCORRES not present";
output PC2;
delete;
end;
if PCSTRESN ne . and (PCSTRESC = "" or PCORRES = "") then do;
Error="Alert: PCSTRESN present but PCSTRESC or PCORRES not present.";
output PC2;
delete;
end;
if anyalpha(PCSTRESC) = 0 and findc(PCSTRESC,'!"#$%&''()+-.')= 0 and PCSTRESC ne "" and PCSTRESN = . then do;
Error="Alert: PCSTRESC present and numeric but PCSTRESN not present.";
output PC2;
delete;
end;
if PCORRESU ne "" and PCSTRESU = "" then do;
Error="Alert: PCORRESU present and numeric but PCSTRESU not present.";
output PC2;
delete;
end;
if PCSTRESU ne "" and PCORRESU = "" then do;
Error="Alert: PCSTRESU present and numeric but PCORRESU not present.";
output PC2;
delete;
end;
output source.PC1;
run;


/*Create Empty target dataset and with attributes from metadata and populate*/

data target.PC(drop=Error);
set Empty_PC source.PC1;
run;

**** SORT PC ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=PC) 

proc sort data=target.PC; 
by &PCSORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.PC file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\PC.xpt" ; 
run;
