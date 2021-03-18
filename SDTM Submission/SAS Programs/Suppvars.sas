PROC IMPORT OUT= SOURCE.SUPPVARS 
            DATAFILE= "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel
 Files\SUPPvars.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
RUN;
