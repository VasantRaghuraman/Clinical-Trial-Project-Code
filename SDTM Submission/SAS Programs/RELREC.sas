/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: RELREC
Programmers: Vasant Raghuraman
Date: June 20, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.RELREC
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_RELREC Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=RELREC)

/*Relationships FOR AE and FAAE domains. Since AESPID is not unique for each USUBJID and AETERM in AE Domain AESEQ

is used even though AESEQ was derived*/

data source.RELRECAEFAAE;
format STUDYID RDOMAIN USUBJID IDVAR IDVARVAL RELTYPE RELID;
length IDVARVAL $10 RELTYPE $4 IDVAR $8;
STUDYID="EFC10547";
RDOMAIN="AE";
USUBJID="";
IDVAR="AESEQ";
IDVARVAL="";
RELTYPE="ONE";
RELID="AE-FAAE";
output;
RDOMAIN="FAAE";
IDVAR="FAGRPID";
RELTYPE="MANY";
output;
run;

/*For relationship between DS and AE. Since it is not easy to establish relationship between DS nd AE from the data provided
it is to be sent to Clinical data management for further clarificatiion*/

/*Relationship between EX and EC*/
data source.RELRECEXEC;
format STUDYID RDOMAIN USUBJID IDVAR IDVARVAL RELTYPE RELID;
length IDVARVAL $10 RELTYPE $4 IDVAR $8;
STUDYID="EFC10547";
RDOMAIN="EC";
USUBJID="";
IDVAR="ECSEQ";
IDVARVAL="";
RELTYPE="ONE";
RELID="EC-EX";
output;
RDOMAIN="EX";
IDVAR="EXSEQ";
RELTYPE="ONE";
output;
run;

/*PC and PP domains. PP will be calculated from ADAM*/

/*For TU,TR and RS domains*/

data source.RELRECTUTRRS;
format STUDYID RDOMAIN USUBJID IDVAR IDVARVAL RELTYPE RELID;
length IDVARVAL $10 RELTYPE $4 IDVAR $8;
STUDYID="EFC10547";
RDOMAIN="TU";
USUBJID="";
IDVAR="TULINKID";
IDVARVAL="";
RELTYPE="ONE";
RELID="TU-TR";
output;
RDOMAIN="TR";
IDVAR="TRLNKID";
RELTYPE="MANY";
output;
RDOMAIN="TR";
IDVAR="TRLNKGRP";
RELTYPE="MANY";
RELID="TR-RS";
output;
RDOMAIN="TR";
IDVAR="RSLNKGRP";
RELTYPE="ONE";
output;
run;

/*Relationship between DS and SS*/

data source.dsae1;
set target.DS;
if DSSCAT="DEATH";
run;

data source.DSAE2;
set target.AE;
if AESDTH="Y";
run;

data source.DSAE3;
set target.SS;
if SSORRES="DEATH";
run;


data source.RELRECSSDS;
format STUDYID RDOMAIN USUBJID IDVAR IDVARVAL RELTYPE RELID;
length IDVARVAL $10 RELTYPE $4 IDVAR $8;
STUDYID="EFC10547";
RDOMAIN="DS";
USUBJID="";
IDVAR="DSSCAT";
IDVARVAL="DEATH";
RELTYPE="ONE";
RELID="DS-SS";
output;
RDOMAIN="SS";
IDVAR="SSORRES";
RELTYPE="ONE";
output;
run;

data source.RELREC;
set source.RELRECEXEC source.RELRECEXEC source.RELRECTUTRRS source.RELRECSSDS;
run;


/*Create Empty target dataset and with attributes from metadata and populate*/

data target.RELREC;
set EMPTY_RELREC source.RELREC;
run;

**** SORT RELREC ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=RELREC) 

proc sort data=target.RELREC; 
by &RELRECSORTSTRING; 
run;


/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.RELREC file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\RELREC.xpt" ; 
run;
