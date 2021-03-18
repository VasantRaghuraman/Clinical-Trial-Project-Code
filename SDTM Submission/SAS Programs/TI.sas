%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TI)

/* Inserting values into target.Ti dataset based on the Trial Design Matrix and supplied values in source.ti dataset*/

    proc import 
        datafile="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\ti.csv"
        out=source.ti
        dbms=csv
        replace;
		guessingrows=max;
    run;


data target.ti;
set Empty_TI source.ti;
run;

**** SORT TI ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TI) 

proc sort data=target.TI; 
by &TISORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.TI file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\TI.xpt" ; 
run;

;*';*";*/;
