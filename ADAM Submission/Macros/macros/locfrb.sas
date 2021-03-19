/*Macro to do LOCF or Next observation carried backward*/

%macro locfrb(inds=, /* Input data set (required) */
 outds=&inds, /* Output data set, defaults to input */
 byvars=, /* Ordering columns */
 groupvar=t_var02, /* By group to carry forward within */
 var=, /* Column to be processed (required) */
 newvar=, /* Column for created values (optional) */
 diffirst=t_var06, /* Diff. from 1st &GROUPVAR (optional) */
 difflast=t_var07, /* Diff. from last &GROUPVAR (optional) */
 difffwd=t_var08, /* Diff. from prior value (optional) */
 diffrev=t_var09, /* Diff. from following value (optional) */
 dir=F, /* Carrying direction (def. forwards) */
 nullval= ); /* User defined null value (optional) */

%local sortkey dds dtype dlength;
/*** Determine the data type and length of VAR */
 proc sql noprint nofeedback;
 select upcase(type), length into :dtype, :dlength from
 dictionary.columns
 where upcase(libname)='WORK' and upcase(memname)="%upcase(&inds)"
 and upcase(name)="%upcase(&var)";
 quit;
/*** Set up the default GROUPVAR if none specified */
%if &groupvar= and &byvars ne %then %do;
 %let groupvar=%scan(&bayvars,-1);
%end;
%else %if &groupvar= and &byvars= %then %do;
 %let groupvar=t_var02;
%end;
/*** Set the default null value, missing or blank. Allocate the sort key */
%if &nullval= %then %do;
 %if &dtype=NUM %then %do;
 %let nullval=.;
 %end;
 %else %do;
 %let nullval=%str(' ');
 %end;
%end;
%let sortkey=&byvars t_var02 t_var03;
/*** Keep the original values of &VAR. t_var02 is a dummy key, t_var03 is */
/*** a key of the original observation sequencing. This is used as the */
/*** sortkey if no BYVARS are specified. Sort by the BYVAR variables */

data t01;
 set &inds;
 %if &dtype=CHAR %then %do;
 length o_&var $&dlength;
%end;
 o_&var=&var;
 t_var02=1;
 t_var03=_n_;
 run;
 proc sort data=t01;
 by &sortkey;
 run;
/*** Perform the forward pass if direction is forward or both. If &VAR is */
/*** is character create a temporary holding variable of the same length */
 data t01;
 set t01;
 by &sortkey;
%if &dtype=CHAR %then %do;
 length t_var01 $&dlength; %end;
 retain t_var01;
 retain t_var05 t_var06 t_var07;
 t_var04=(first.&groupvar)+2*(last.&groupvar);
 t_var03=_n_;
 if "%upcase(%substr(&dir,1,1))"='F' or "%upcase(%substr(&dir,1,1))"='B'
 then do;
 if t_var04 in (1,3) then do; /* First VAR value in the group */
 t_var01=&var;
 t_var05=.; /* Initialize holding variables to missing */
 t_var06=.;
 t_var07=.;
 end;
%if &dtype=NUM %then %do;
 if t_var05=. then do; /* First value of VAR */
 t_var05=&var;
 end;
 if &var ne . and t_var05 ne . then do; /* Difference from 1st VAR */
 t_var06=&var-t_var05; /* in the group */
 end;
 if &var ne . and t_var01 ne . then do; /* Difference from latest */
 t_var07=&var-t_var01; /* missing VAR (difffwd) */
 end;
 %end;
 if &var=&nullval then do;
 &var=t_var01; /* Carry forward when VAR is null */
 end;
 else do;
 t_var01=&var; /* Keep the latest non-null VAR to carry forward */
 end;
 end;
 run;
/*** Now sort in reverse order for carrying backwards */
 proc sort data=t01(drop=t_var01 t_var05);
 by descending t_var03;
 run;
/*** Perform the backward pass if direction is both or reverse. Repeat the */
/*** above steps but with the data set observations in the reverse order */
 data t01;
 set t01;
 by descending t_var03;
%if &dtype=CHAR %then %do;
 length o_&var t_var01 $&dlength;
%end;
 retain t_var01;
 retain t_var05 t_var08 t_var09;
 if "%upcase(%substr(&dir,1,1))"='R' or "%upcase(%substr(&dir,1,1))"='B'
 then do;
 if t_var04 in (2,3) then do;
 t_var01=&var;
 t_var05=.;
t_var08=.;
t_var09=.;
 end;
%if &dtype=NUM %then %do;
 if t_var05=. then do; /* Last value of VAR */
 t_var05=&var;
 end;
 if o_&var ne . and t_var05 ne . then do; /* Difference from last VAR */
 t_var08=o_&var-t_var05; /* in the group (difflast) */
 end;
 if o_&var ne . and t_var01 ne . then do; /* Difference from next non-*/
 t_var09=o_&var-t_var01; /* missing VAR (diffrev) */
 end;
%end;
 if &var=&nullval then do;
 &var=t_var01; /* Carry backward when VAR is null */
 end;
 else do;
 t_var01=&var; /* Keep the latest non-null VAR to carry backward */
 end;
 end;
%if &newvar ne %then %do; /* Now assign the temporary values to the */
 &newvar=&var; /* corresponding output parameters */
 &var=o_&var;
%end;
%if &diffirst ne t_var06 %then %do;
 &diffirst=t_var06;
%end;
%if &difffwd ne t_var07 %then %do;
 &difffwd=t_var07;
%end;
%if &difflast ne t_var08 %then %do;
 &difflast=t_var08;
%end;
%if &diffrev ne t_var09 %then %do;
 &diffrev=t_var09;
%end;
 run;
 /*** Recreate the input data set with the new columns or create the */
/*** specified output data set. Remove temporary variables */
 proc sort data=t01 out=&outds(drop=t_var0: o_&var);
 by &sortkey;
 run;
%mend locfrb;
