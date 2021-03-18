/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: TA
Programmers: Vasant Raghuraman
Date: Aug 10, 2019
Project: Practice Project in Oncology
Raw Dataset: CSV File "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\TA.csv"
************************************************************************************************/
%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TA)

/* Inserting values into TA dataset based on the Trial Design Matrix and supplied values in ta dataset*/

    proc import 
        datafile="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\ta.csv"
        out=source.ta 
        dbms=csv
        replace;
		guessingrows=max;
    run;



data target.ta;
set Empty_TA source.ta;
run;

**** SORT TA ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TA) 

proc sort data=target.ta; 
by &TASORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.TA file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\TA.xpt" ; 
run;
