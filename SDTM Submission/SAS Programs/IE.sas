/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: IE
Programmers: Vasant Raghuraman
Date: April 14, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.IE
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_IE Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=IE)

/*Capturing data from suplied source dataset*/

data source.IE1(rename=(RUSUBJID=USUBJID));
set Original.IE;
run;

data source.IE2(drop=RSUBJID IETEST1);
set source.IE1;
format IECAT IECAT.;
IECAT=vvalue(IECAT);
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.IE;
set EMPTY_IE source.IE2;
run;

**** SORT IE ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=IE) 

proc sort data=target.IE; 
by &IESORTSTRING; 
run;

/*Create SuppIE Domain*/

%SUPPDOMAIN(dmname=IE)

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.IE file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\IE.xpt" ; 
run;

proc cport data=target.SUPPIE file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPIE.xpt" ; 
run;
