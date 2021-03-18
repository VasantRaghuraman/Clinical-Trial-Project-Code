/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: TD
Programmers: Vasant Raghuraman
Date: Aug 10, 2019
Project: Practice Project in Oncology
Raw Dataset: CSV File "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\TD.csv"
************************************************************************************************/
%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TD)

/* Inserting values into target.TV dataset based on the Trial Design Matrix and supplied values in source.tv dataset*/

    proc import 
        datafile="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\td.csv"
        out=source.td
        dbms=csv
        replace;
		guessingrows=max;
    run;

data target.td;
set Empty_TD source.td;
run;

**** SORT TD ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TD) 

proc sort data=target.td; 
by &TDSORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.TD file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\TD.xpt" ; 
run;
