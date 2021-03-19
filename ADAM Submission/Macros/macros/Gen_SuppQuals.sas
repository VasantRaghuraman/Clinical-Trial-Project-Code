%macro Gen_SuppQuals;
 proc sql noprint;
 select count(distinct Domain) into :nsupps
 from source.suppvars;
 quit;

 %let nsupps = &nsupps.;
 proc sql noprint;
 select distinct Domain into :domain1 - :domain&nsupps.
 from source.suppvars;
 quit;

 %mend Gen_SuppQuals;

