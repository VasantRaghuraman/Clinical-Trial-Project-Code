PROC EXPORT DATA= SOURCE.Ae8 
            OUTFILE= "D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\SUPPAE.csv" 
            DBMS=CSV LABEL REPLACE;
     PUTNAMES=YES;
RUN;
