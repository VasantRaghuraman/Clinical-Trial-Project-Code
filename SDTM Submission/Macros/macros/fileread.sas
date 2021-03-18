%macro fileread(file_list,filenum);

%do j=1 %to &filenum;
data _null_;
 set &file_list;
 if _n_=&j;
 call symput ('filein',fname);
run;

data var_names;
 length x1-x17 $20;
 infile "D:\Clinical SAS Studies\SDY 1\SDY1-DR29_Tab\SDY1-DR29_Tab\Tab\&filein" dlm='09'x dsd lrecl=4096 truncover
obs=1 termstr=LF;
 input (x1-x17) ($) ;
run; 


%macro varnames;
%do i=1 %to 17;
%global v&i; 
data _null_;
 set var_names;
 call symput("v&i",trim(x&i));
run;
%end;
%mend varnames;
%varnames; 

%let dsetname= %scan(&filein,1);

data _null_;
%put &dsetname;
%put &v1 &v2 &v3 &v4 &v5 &v6 &v7 &v8 &v9 &v10 &v11 &v12 &v13 &v14 &v15 &v16 &v17;
run;



data &dsetname;
 infile "D:\Clinical SAS Studies\SDY 1\SDY1-DR29_Tab\SDY1-DR29_Tab\Tab\&filein" dlm='09'x dsd lrecl=4096 truncover
 firstobs=2 termstr=LF;
 length &v1 &v2 &v3 &v4 &v5 &v6 &v7 &v8 &v9 &v10 &v11 &v12 &v13 &v14 &v15 &v16 &v17 $100; 
 input (&v1 &v2 &v3 &v4 &v5 &v6 &v7 &v8 &v9 &v10 &v11 &v12 &v13 &v14 &v15 &v16 &v17)($);
run; 

%end;

%mend fileread;


