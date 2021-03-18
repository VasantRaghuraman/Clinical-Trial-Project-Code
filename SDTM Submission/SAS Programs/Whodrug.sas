PROC EXPORT DATA= WORK.cmdec 
            OUTFILE= "D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata
\Whodrug.csv" 
            DBMS=CSV LABEL REPLACE;
     PUTNAMES=YES;
RUN;
