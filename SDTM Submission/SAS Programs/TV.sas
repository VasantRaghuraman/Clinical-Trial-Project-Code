%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TV)

/* Inserting values into target.TV dataset based on the Trial Design Matrix and supplied values in source.tv dataset*/

    proc import 
        datafile="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\tv.csv"
        out=source.tv
        dbms=csv
        replace;
		guessingrows=max;
    run;


data target.tv;
set Empty_TV source.tv;
run;

**** SORT TV ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TV) 

proc sort data=target.tv; 
by &TVSORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.TV file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\TV.xpt" ; 
run;
