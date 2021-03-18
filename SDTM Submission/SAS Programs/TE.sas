%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TE)

/* Inserting values into target.TE dataset based on the Trial Design Matrix and supplied values in source.te dataset*/

    proc import 
        datafile="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\te.csv"
        out=source.te
        dbms=csv
        replace;
		guessingrows=max;
    run;
							
proc sql;
create table target.te like Empty_te;
quit;


data target.te;
set target.te source.te;
run;

**** SORT TE ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=TE) 

proc sort data=target.te; 
by &TESORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.TE file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\TE.xpt" ; 
run;

;*';*";*/;
