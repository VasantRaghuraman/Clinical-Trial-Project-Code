/**
 * Obtains variable count from a Dataset.
 *
 * @param dsn Dataset Name to retrieve variable information from.
 * @return nvars Number of Variables in Dataset.
 **/
%macro nvars(dsn);
   %let dataset=&dsn;
   %let dsid = %sysfunc(open(&dataset));
   %if &dsid %then %do;
      %let nvars=%sysfunc(attrn(&dsid,NVARS));
      %let rc = %sysfunc(close(&dsid));
   %end;
   %else
      %put Open for data set &dsn failed - %sysfunc(sysmsg());
&nvars
%mend nvars;
