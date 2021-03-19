/*Merge Supplementary datasets*/

options MPRINT;

%macro SUPP2PAR_v1(
 inlib=, /* Name of input library for Parent and Supplemental Datasets */
 parent=, /* Name of Parent dataset */
 supp=, /* Name of Supplemental dataset */
 outlib=, /* Name of destination library for Merged dataset */
 outname=, /* Name of Merged dataset */
 clean=, /* Whether or not (Y/N) to clean work environment at end */
 dev=, /* Whether or not (Y/N) to show all messages in the log */
 Info=, /* Level of information to provide in the log:
 1 (all), 2 (start and summary), 3 (only summary) */
 RC= /* Name of Return Code Macro variable */);

 proc transpose data = &inlib..&supp (rename = (RDOMAIN = DOMAIN))
 out = &outlib..&supp.T (drop = _NAME_ _LABEL_);
 by STUDYID DOMAIN USUBJID IDVAR IDVARVAL; 
 var qval; 
 id qnam; 
 idlabel qlabel; 
run;

data &outlib..&outname &outlib..&outname._DROP;
 merge &inlib..&parent (in = PARENT) &inlib..&supp (in = SUPP); 
 by STUDYID DOMAIN USUBJID IDVAR IDVARVAL; 
 if PARENT then output &outlib..&outname; 
 else if SUPP and not(PARENT) then &outlib..&outname._DROP; 
run;

%mend;
