%macro std_units(in_ds=lb, byvars=lbtestcd, unit_ds=units, out_ds=lb_unit, all=Y);

    proc sort data=&in_ds. out=&in_ds.s;
       by &byvar.;
    run;

    proc sort data=&unit_ds. out=&unit_ds.s;
      by &byvar.;
    run;

   data=&unit_ds. ;
     merge &in_ds.s(in=a) &unit_ds.s(in=b);
     by &byvars.;

     %if &all.=N %then
       %do;
         if a and b;
       %end;
     %else
       %do;
         if a;
       %end;
  run;
%mend std_units;
