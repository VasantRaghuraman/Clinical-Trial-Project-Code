* The following macro variables are available for optional calculation: *;
* unit - units to calculate AAGE variable *;
* default: Y *;
* permitted values: Y M D *; * ref_date – reference variable to calculate age. *;
* default: RANDDT *;
* permitted values: RANDDT TRTSDT RFICDT *;
options minoperator; 
%macro age_deriv ( unit = ,ref_date = ) / minoperator;
%if not(%upcase(&unit.) in (Y M D YEARS MONTHS DAYS)) %then %put %str(WARN ING: Impossible Units);
%else %if not(%upcase(&ref_date.) in (RANDDT TRTSDT RFICDT)) %then %put %str(WARN ING: Improper reference variable) ;
%else %do;

/* Choose certain values according to macro options */ %if %upcase(&unit.) = Y or %upcase(&unit.) = YEARS %then %do; 
%let factor = 365.25; 
%let _ageu = "YEARS"; 
%end;

%if %upcase(&unit.) = M or %upcase(&unit.) = MONTHS %then %do; 
%let factor = 30.4375; 
%let _ageu = "MONTHS"; 
%end;

%if %upcase(&unit.) = D or %upcase(&unit.) = DAYS %then %do; 
%let factor = 1; 
%let _ageu = "DAYS"; 
%end;

data adsl; 
set adsl;
length ageu $6. aage; ageu = &_ageu.;
if missing(&ref_date.) then put "WARN" "ING: Reference date is missing. Please check USUBJID = " USUBJID;
else aage = int((&ref_date. - brthdt +1)/&factor.);
if aage ^= age then put "NOTE: Analysis Age and Age var from DM are different for USUBJID = " USUBJID ;
run; 
%end; 

%mend age_deriv;
