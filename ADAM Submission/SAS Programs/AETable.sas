data AE1(keep=USUBJID AEPT AESOC AESER AETOXGR AETOXGRN);
set target.AE;
AEPT=AEDECOD;
AETOXGRN=input(AETOXGR,8.);
run;

libname target "D:\Pancrea_SanofiU_2007_134\ADAM Submission\SAS Programs";

data ADSL1(keep=USUBJID TRTA TRTAN);
set target.ADSL;
TRTA=ACTARM;
TRTAN=TRT01PN;
run;

proc sql;
create table source.ADAE1 as
select AE.USUBJID, AE.AEPT, AE.AESOC, AE.AESER, AE.AETOXGR, AE.AETOXGRN, ADSL.TRTA, ADSL.TRTAN
from AE1 as AE
left join
ADSL1 as ADSL
on AE.USUBJID=ADSL.USUBJID;
quit;
