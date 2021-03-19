%macro empty_var_checking(cdisc = , /* SDTM or ADaM */
 specdir = , /* a folder for programming specs. */
 datadir = , /* a folder for SDTM or ADaM datasets */
 domain = _ALL_/*SDTM or ADaM domain name for checking */
 ); 

*** get the variables from specifications;
data specs_allvars;
 set speclib.all_vars;
 %if %upcase(&domain.) ne _ALL_ %then where domain = upcase("&domain.");;
run;
proc sort data = specs_allvars; by domain variable; run;
*** get the variables from dataset;
proc contents data=datalib.&domain. noprint
 out=data_allvars(rename=(memname=domain name=variable));
run;
proc sort data=data_allvars; by domain variable; run;
data allvars;
 merge specs_allvars(in=a keep=domain variable) data_allvars(in=b);
 by domain variable;
 if a;
run;
data _null_;
 set allvars(keep=domain variable) end=done;
 by domain variable;
 retain numdomain numvar 0;
 if first.domain then do;
 numdomain + 1; numvar = 0;
 call symput('dsn'||strip(put(numdomain,best.)),strip(domain));
 end;
 numvar + 1;
 call symput('var_'||strip(put(numdomain,best.))||'_'||strip(put(numvar,best.)),
 strip(variable));
 call symput('varmfl_'||strip(put(numdomain,best.))||'_'||strip(put(numvar,best.)),
 'mfl_'||strip(variable));
 if last.domain then call symput('numvar'||strip(put(numdomain,best.)),
 strip(put(numvar,best.)));
 if done then do; call symput('numdomain',strip(put(numdomain,best.))); end;
run; 

/*  Missing records for each variable are counted and empty variables (if the number of missing records is equal to the
total number of the observations) are output as vertical structure. */

data all;if 0;run;
%do i=1 %to &numdomain.;
 data &&dsn&i;
 set datalib.&&dsn&i end=eof;
 retain %do j=1 %to &&numvar&i.;&&varmfl_&i._&j. %end; 0;
 %do j=1 %to &&numvar&i.;
 if missing (&&var_&i._&j.) then &&varmfl_&i._&j. + 1;
 %end;
 if eof then do; nobs = _n_; output; end;
 run;
 data _tmp;
 set &&dsn&i;
 %do j=1 %to &&numvar&i.;
 domain = "&&dsn&i";
 variable = "&&var_&i._&j.";
 nmissing = &&varmfl_&i._&j.;
 if nmissing = nobs then output;
 %end; 

keep domain variable nmissing nobs;
 run;
 data all; set all _tmp; run;
%end; 

/* Reports are generated based on empty variables in SDTM or ADaM datasets, and the core variable categories of
the variables. */

data final;
 merge all(in=a) specs_allvars(keep=domain variable varnum label core);
 by domain variable;
 if a;
 length COMMENT $100;
 source = "&CDISC.";
 %if %upcase(&CDISC) = SDTM %then %do;
 if core = 'Req' then do; coren = 1;
 comment='Error: Required Variable is Empty. Correct/Check the SAS
 Program!'; end;
 if core = 'Exp' then do; coren=2;
 comment='Warning:Expected Variable is Empty.Check the SAS Program!';
 end;
 if core = 'Perm' then do; coren = 3;
 comment='Warning: Permissible Variable is Empty. Delete it?'; end;
 %end;
 %if %upcase(&CDISC) = ADAM %then %do;
 if core = 'Req' and variable in ('STUDYID', 'SITEID', 'USUBJID', 'SUBJID',
 'PARAMCD', 'PARAM', 'SEX', 'RACE', 'ARM', 'COUNTRY') then do; coren = 1;
 comment='Error: Required Variable is Empty. Correct/Check SAS Program!';
 end;
 else if core = 'Req' then do; coren = 2;
 comment='Warning: Required Variable is Empty. Check the SAS Program!';
 end;
 if core = 'Cond' then do; coren = 3;
 comment='Warning:Conditionally Required Variable is Empty.Check the SAS
 Program!'; end;
 if core = 'Perm' then do; coren = 4;
 comment='Warning: Permissible Variable is Empty. Delete it?';
 end;
 %end;
run;
proc sort data = final;by domain coren varnum;run;
