/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: LB
Programmers: Vasant Raghuraman
Date: May 18, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.LB
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_LB Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=LB)

proc sql;
create table source.LBPR as
select LB.*, RFST.RFSTDT
from original.LB as LB
left join
source.RFSTDTFIN as RFST
on LB.RUSUBJID=RFST.USUBJID;
quit;

/*Capturing data from supplied source dataset for VISITNUM = 0 to identify tumors at baseline*/

data source.LB1(rename=(RUSUBJID=USUBJID) DROP=RSUBJID LBUPCR LBTM LBENTM LBORNRU LBBLRES LBBLCHG LBTM LBENDT LBENDTM LBENDY LBSCAT RFSTDT);
format STUDYID DOMAIN RUSUBJID LBSEQ LBSPID LBTESTCD LBTEST LBCAT LBSCAT LBORRES LBORRESU LBORNRLO LBORNRHI LBSTRESC 
       LBSTRESN LBSTRESU LBSTNRLO LBSTNRHI LBNRIND LBBLFL LBTOX LBTOXGR VISITNUM VISIT LBDY LBDTC LBENDY LBENDTC LBTPT LBTPTNUM;
set source.LBPR;

if LBDY ne . then do;
if LBDY>0 then LBDT=RFSTDT+LBDY-1;
if LBDY<0 then LBDT=RFSTDT+LBDY;
end;
else LBDT = .;


if LBENDY ne . then do;
if LBENDY>0 then LBENDT=RFSTDT+LBENDY-1;
if LBENDY<0 then LBENDT=RFSTDT+LBENDY;
end;
else LBENDT = .;

LBDTC="";


if LBENDT ne . then do;
	if LBENTM ne . then do;
			LBENDTM=dhms(LBENDT,0,0,LBENTM); 
			LBENDTC=put(LBENDTM,IS8601dt.);
	end;
	else LBENDTC=put(LBENDT,IS8601da.);
end;
else LBENDTC="";


if LBTESTCD="UPCR" then do;
LBORRES=LBSTRESC;
LBORNRLO="0";
LBORNRHI="1";
LBORRESU="RATIO";
end;


LBTESTCD=put(LBTESTCD,$LBTESTCD.);
LBTEST=put(LBTEST,$LBTEST.);
LBORRESU=put(LBORRESU,$UNIT.);
LBSTRESU=put(LBSTRESU,$UNIT.);
LBSTRESC=put(LBSTRESC,$LBSTRESC.);
VISIT=put(VISITNUM,VISIT.);
LBMETHOD=put(LBSCAT,$METHOD.);

run;

/*Since toxicity grades are provided from lab provided normal ranges already, no conversion is made.
Since LBSEQ is already in order, it is also not created, In the interest of saving time, the conversions are 
accepted as provided. In actual Standard values and unit conversions will need to be checked*/

/*Create VISIT and VISITNUM from SV domain*/

proc sql;
create table source.LB2 as
select LB1.STUDYID, LB1.DOMAIN, LB1.USUBJID, LBSEQ, LBSPID, LBTESTCD, LBTEST, LBCAT, LBORRES, LBMETHOD, LBORRESU, LBORNRLO, LBORNRHI, LBSTRESC, 
       LBSTRESN, LBSTRESU, LBSTNRLO, LBSTNRHI, LBNRIND, LBBLFL, LBTOX, LBTOXGR, SV.VISITNUM, SV.VISIT,
       LBDY, LBDTC, LBENDTC, LBTPT, LBTPTNUM
from source.LB1 as LB1
left join
source.svcombine1 as sv
on LB1.USUBJID=SV.USUBJID and LB1.LBDT>=sv.SVSTDT and LB1.LBDT<=sv.SVENDT
order by USUBJID, LBSEQ;
quit;

proc sort data=source.LB2;
by USUBJID LBSEQ VISITNUM;
run;

proc sort data=source.LB2 nodupkey;
by USUBJID LBSEQ;
run;

/*Create Empty target dataset and with attributes from metadata and populate*/

data target.LB;
set EMPTY_LB source.LB2;
run;



















/*QC checks for Lab data*/

/*Check 1: LBTEST, LBTESTCD Lengths must be 40, 8 characters respectively-Complete */
/*----Check for lengths of LBTEST, LBTESTCD-----*/
proc contents data = target.LB out=check1 (keep= NAME LENGTH) noprint;
run;

data check1;
 set check1;
 if NAME ='LBTEST' and LENGTH >40  then Error ='ALERT_R: Length of LBTEST is more than 40, must be <=40' ;
 else if NAME ='LBTESTCD' and LENGTH >8 then Error= 'ALERT_R: Length of LBTESTCD is more than 8, must be <=8';
run;

/*Check 2: Unique LBSTRESU for LBCAT/LBTEST/LBTESTCD/LBSPEC/LBMETHOD: */

/*Check for unique standard unit per LBCAT/LBTEST/LBTESTCD/LBSPEC/LBMETHOD* - Here LBSPEC and LBMETHOD are ignored**/

proc sort data = target.LB nodupkey out = check2
(keep = LBCAT LBTEST LBTESTCD LBMETHOD LBSTRESU);
 by LBCAT LBTEST LBTESTCD LBMETHOD LBSTRESU;
run;

data check2;
 set check2;
 by LBCAT LBTEST LBTESTCD LBMETHOD LBSTRESU;
 if first.LBTEST ne last.LBTEST and first.LBMETHOD ne last.LBMETHOD then do;
 if first.LBTEST then
 Error= "ALERT_R: Non-Unique Standardized unit present for  LBTEST LBMETHOD test. Requires review" ;
 put LBTEST=;
 end;
run; 

/*Approach 2: Writing these issues to SAS datasets and then write to Excel file to consolidate issues for
communication purpose. 

proc sort data = Lbinput out = check2
(keep = LBCAT LBTEST LBTESTCD LBSPEC LBMETHOD LBSTRESU);
 by LBCAT LBTEST LBTESTCD LBSPEC LBMETHOD LBSTRESU;
run;
proc freq data = check2 noprint;
 tables LBCAT*LBTEST* LBTESTCD* LBSPEC* LBMETHOD* LBSTRESU/
 out = check2 list nocum nopercent;
run;
data check2;
 set check2;
 by LBTEST LBTESTCD LBCAT LBSPEC LBMETHOD LBSTRESU;
 if first.LBTEST ne last.LBTEST ;
run; */

/*Check 3: LBSTRESU is missing but LBSTRESN are present.-Complete*/
/*-Check for missing LBSTRESU while LBSTRESN are not missing-*/
proc sort data = target.LB
 (where=(LBSTRESN ne . and LBSTRESU eq ""))
 out= check3(Keep= LBCAT LBTEST LBTESTCD LBMETHOD LBSTRESU
 LBORRESU) nodupkey;
 by LBCAT LBTEST LBTESTCD LBMETHOD;
run;

data check3;
 set check3;
 by LBCAT LBTEST LBTESTCD LBMETHOD;
 if last.LBTEST then do;
 Error= "ALERT_R: Standard unit is missing for  LBTEST  test. Requires review";
 end;
run; 

/*Check 4: Check for duplicate records on key variables - Complete */
/*-Check for identifying duplicate records-*/
proc sort data = target.LB tagsort NOUNIQUEKEY UNIQUEOUT= Lb
 out=check4;
 by USUBJID LBCAT LBTEST LBTPTNUM VISITNUM LBDTC;
run;

data check4;
 set check4;
 by USUBJID LBCAT LBTEST LBTPTNUM VISITNUM LBDTC;
 if first.USUBJID ne last.USUBJID then
 Error= "ALERT_R: Duplicate records for subject  USUBJID LBTEST  test. Requires review";
run; 

/*Since this check revealed several duplicate records, the non-duplicate records are now considered for 
the remaining tests and the final output Send Check4 to CDM**/
data target.LB(drop=LBSCAT);
set Empty_LB LB;
run;

/*Check 5: Is Reference range indicator missing while original result/standard result and ranges are present?- Complete*/
/*-Check for identifying missing LBNRIND records while result and ranges are present. Send Check5 to CDM-*/

data check5 target.LB;
 set target.LB;
 if LBSTRESN ne . and LBSTNRHI ne . and LBSTNRLO ne . and LBNRIND=""  then do;
 Error= "ALERT_R: Reference range indicator is missing even though normal ranges are present. Requires review";
 output check5;
 delete;
 end;
 output target.LB;
run; 


/*Check 6: Check for derived reference range indicator values.-Complete*/
/*-Check for identifying incorrectly derived LBNRIND records -*/
data check6 target.LB;
 set target.LB;
 if LBSTRESN ne . then do;
 if LBSTRESN>LBSTNRHI and LBSTNRHI ne . and LBNRIND ne "HIGH" then do;
      ERROR="HIGH value derived incorrectly";
      output check6;
	  delete;
	  end;
 if LBSTRESN<LBSTNRLO and LBSTNRLO ne . and LBNRIND ne "LOW" then do;
      ERROR="LOW value derived incorrectly";
      output check6;
	  delete;
	  end;
 if LBSTRESN>=LBSTNRLO and LBSTRESN<=LBSTNRHI and LBSTNRLO ne . and LBSTNRHI ne . and LBNRIND ne "NORMAL" then do;
      ERROR="NORMAL value derived incorrectly";
      output check6;
	  delete;
	  end;
 end;
 output target.LB;
Run; 

/*Check 7: Check for Origin of SDTM variable- To be completed as part of excel file loaded into Pinnacle 21*/

/*Check 8: LBSTRESC is expected to be populated for Baseline records (LBBLFL='Y')*/
/*-Check for identifying incorrectly derived LBBLFL records -*/
data check8 target.LB;
 set target.LB;
 if LBBLFL ='Y' and LBSTRESC ="" then do;
 Error= "ALERT_R: Record is flagged as baseline even though test is not done/result is missing  USUBJID LBSEQ Requires review";
 output check8;
 delete;
end;
output target.LB;
run; 

/*Check 9: Check for records with missing LBSTRESC while LBORRES is provided*/
/*-Check for identifying missing LBSTRESC records while LBORRES not missing-*/
data check9 target.LB;
 set target.LB;
 if LBORRES ne "" and LBSTRESC eq "" then do;
Error="ALERT_R: Standard result is missing while original result is not missing Requires review";
output check9;
delete;
end;
output target.LB;
run; 

/*Check 10: Check for missing LBSTRESN while LBSTRESC is provided and represents a numeric value*/
/*-Check for identifying missing LBSTRESN records while LBSTRESC is not missing-*/
data check10 target.LB;
 set target.LB;
 if anyalpha(LBSTRESC) =0 and findc(LBSTRESC,'!"#$%&''()+-')= 0 then do;
 if LBSTRESN eq . and input(LBSTRESC,8.) ne . then do;
Error="ALERT_R: LBSTRESN result is missing while LBSTRESC result has numeric value Requires review";
output check10;
delete;
end;
end;
output target.LB;
run; 
 

/*Check 11: Missing value for LBSTRESC, while LBSTRESU is provided */
/*-Check for identifying missing LBSTRESC records while LBSTRESU is not missing-*/

data check11 target.LB;
 set target.LB;
 if (LBSTRESC eq "" and LBSTRESU ne "") or (LBORRES eq "" and LBORRESU ne "" ) then do;
 Error= "ALERT_R: Units are populated while results are missing Requires review";
 output check11;
 delete;
 end;
 output target.LB;
run;

/*Check 12: Check to see if lab result is present and it is numeric but with missing corresponding original unit*/
/*-Check for identifying missing LBORRESU records while LBORRES is provided*/
data check12 target.LB;
 set target.LB;
 if anyalpha(LBORRES) =0 and findc(LBSTRESC,'!"#$%&''()+-')> 0 then do;
 if input(lborres,8.) ne . and lborresu = "" then do;
 Error= "Alert_R: has records with reported result that has numeric result values but do not have corresponding unit";
 output check12;
 delete;
 end;
 end;
 output target.LB;
run; 

/*Understand the Domain
The laboratory domain (LB) captures laboratory data collected in the case report form (CRF) or received from a central provider or vendor. Very often there are only two values to be summarized per subject and parameter: baseline and maximum on treatment value. For example values outside the normal ranges and toxicities, as defined per National Cancer Institute Common Terminology Criteria for Adverse Events (NCI CTCAE), may also be summarized. There are also other toxicities grading systems including Rheumatology Common Toxicity Criteria (RCTC) and Division of Aids (DAIDS) to name a few that could be considered.  Sometimes laboratory test values are summarized per treatment cycle or epoch, more complicated outputs include:

Summarising abnormalities overlapping with other abnormalities or specific Adverse Events. One example is Hy’s Law analysis
CTC grades analysis, including shift tables 

Study Requirements
Before the statistical programming commences , there are few required actions to perform:

Check the analysis plan and table mocks to determine the programming outputs that are required
Discuss how to handle duplicates with the study team.
Review available tests, specimen types and categories for potential exclusions
Verify the sorting key (Clinical Data Interchange Standards Consortium (CDISC) recommendation is that you have one record per laboratory test, time point, visit and subject)
Exclusions may also be performed on the category level (for example: urinalysis), specimen level or test level.
See table below for an example of specimen exclusions for potassium:

Mapping Checks
In addition to the study requirements discussed above, the following mapping checks are suggested:

Check if each test has a unique category. When reporting by laboratory category, if a test is assigned to multiple categories (as shown in the table above) this may result in the same test being reported in different tables. In this case, verify in which table each test belongs, for example, the haematology category may feed into chemistry or be a separate table
Check if specimens should be grouped for reporting, for example, the three specimens: arterial blood, blood and venous blood can all be mapped to blood
Examine if test codes and names map one-to-one at least within a category. Below is an example of mapping laboratory test names

Qualitative Values
Not all tests will have continuous numeric results, examples may be urinalysis tests like ketones, glucose, and protein. Qualitative values can be mapped as follows:

to other qualitative values: N, NEG, NEGATIV, NONE-DETECTED → NEGATIVE
to quantitative values: ++, +++, ++++, +1, 1+, POSITIVE, Positive → 1
                                                   >60 → 60.01

Simple mapping of collected terms to standardized terms can be done in the SDTM datasets, however this does not include imputations such as >6 → 60.01 which should be done in the analysis ADaM dataset instead as no imputations should be done in the SDTMs. Care should be taken to follow the CDISC Implementation Guides for how to populate the Original, Standard and Analysis results across the datasets. If there are no units associated with a result it does not necessarily mean that it is qualitative. Example tests with quantitative results and no unit are pH or Specific Gravity.

Conversion of Units
There is the possibility to choose from many unit standards, which one to follow is up to your clinical team. Some example standards are the Système International (SI) unit, the U.S. Conventional units or Client-specific standard. See table below for examples of the differences between units:

It is strictly recommended to check that all units follow the agreed standard, if not, unit conversion should be applied. The unit 10**6/MM*3 for CDISC STDM should be mapped to CDISC Controlled Terminology equivalent. This is a CDISC SDTM requirement and all units should be mapped to the equivalent CDISC CT Submission Value where possible. Conversion of units is done by multiplying the original lab test value by the specified conversion factor. The clinical team will provide you with missing conversion factors; these would also be needed to convert lower and upper limits of the reference range where populated, unless new ranges are being applied for consistency across the dataset. Conversion may depend on the laboratory test – see tables below:

In addition, the checking of outliers in the converted observations is recommended as sometimes the initial unit is incorrectly assigned and the conversion was not in fact needed. 

Conversion of units may be time-consuming, especially if each non-standard unit is handled separately. This would also significantly increase the size of the SAS program and make the code cumbersome to read. It is therefore worth considering writing a reusable program for unit conversion.
The initial step for the conversion process would be making sure that the laboratory dataset contains the standard unit for each test, i.e., the unit that will be used for the reporting; exceptions are laboratory tests for which units are not required. It is good practice to keep a list of reporting units in an external file (.txt, .csv, .xls), which in this form can be easily read in SAS and transformed to a SAS dataset; moreover, all potential updates will require only an update to the external file and rerun of a previously created code.

If a dataset of conversion factors is not provided to the programming team, it can be created by programmers and submitted for clinical review and approval. For conversions which are not dependent on the test (for example g/dL to g/L), the dataset with conversion factors should contain at a minimum: original unit, conversion factor and reporting unit. For conversions specific to the laboratory tests the dataset should additionally contain variable(s) allowing identification of the test, such as the Lab Test Code or the Lab Test Name. The final dataset should contain unique records only, in order to avoid duplication of laboratory records.

The below macro call can be used for merging the laboratory dataset with the dataset containing reporting units:

/* Macro for merging laboratory dataset (in_ds) with dataset containing reporting units (unit_ds) for each test.
Datasets are merged by common variables (byvars) which:
- are specific to the project, 
- identify unique lab test. 
Example merge key can be: 
- Lab Test Name and Specimen Type, Lab Test Code, LOINC code. 
‘all’ variable specifies the content of the output dataset (out_ds): 
- only records with reporting unit found in unit_ds dataset (all=N) or 
- all records, irrespective of the corresponding reporting unit found in unit_ds dataset or not */
/*
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

Once the reporting units are in the dataset, the next step is to use the conversion dataset to obtain the conversion factor for each pair of original and standard units, as in the code below:*/

/* lb - laboratory dataset
conv - conversion dataset
factor - conversion factor variable
org_unit - original unit variable
rep_unit - reporting unit variable
lbtestcd - lab test code variable, in this example it is identifying variable for lab test. Lbtestcd is used to assign factors for conversion dependent on lab test (a.lbtestcd=b.lbtestcd); for conversion not dependent on lab test lbtestcd is missing in conv dataset.
proc sql;
create table lb_conv as select a.*, b.factor
  from lb as a left join conv as b 
    on upcase (a.org_unit)=upcase (b.org_unit)
    and upcase (a.rep_unit)=upcase (b.rep_unit)
    and (a.lbtestcd=b.lbtestcd or missing(b.lbtestcd))
  order by a.lbtestcd;
quit; */
/*
A simple macro for unit conversion is included below. This macro should be called within a data step and the conversion applied only to records where:
 

the original unit and the reporting unit are not equal
the result in the original unit and factor variables are not missing
the result is numeric (i.e. contains only digits and ‘.’)

The conversion of units is done by multiplying the result in the original unit by the specified conversion factor. As a result of calling the below macro, values are assigned to reporting unit, numeric and character result in the reporting unit and reference ranges for lower and upper limits. The macro parameter “&conv_ln” can be used to switch off the conversion of lower and upper limits; however the default and highly recommended option (presented below) is that the conversion is done. Additionally, the variable “convfl” is created to flag records that have been converted and to aid quality checks of the conversion. 

In the example below a specific format for the results is not required, however, 
standard specific or study-specific numeric result precision may be expected.*/
/* conv_ln – macro parameter, specify if lower and upper limits of range should be converted (conv_ln=Y) 
rep_unit – reporting unit 
factor – conversion factor 
convfl – flag for converted observations 
standard CDISC variables: 
lborres – result or finding in original units 
lborresu – original units 
lbsrtesu - standard units 
lbstresn – numeric result/finding in standard units 
lbstresc – character result/finding in standard format 
lbornrlo – reference range lower limit in original unit 
lbornrhi – reference range upper limit in original unit 
lbstnrlo – reference range lower limit - standard units 
lbstnrhi – reference range upper limit - standard units 
%macro conversion(conv_ln=Y); 
   %let conv_ln=%upcase l(&conv_ln);
   if upcase(lborresu) ne upcase(rep_unit) and cmiss(factor, 
 lborres)=0 and findc(lborres, '.', 'dkt')=0 then
     do;
       lbstresu=rep_unit;
       lbstresn=input(lborres, best.)*factor;
       lbstresc=strip(put(lbstresn, best.));

       %if &conv_lnest. = Y %then 
         %do;
           lbstnrlo=input(lbornrlo, best.)*factor;
           lbstnrhi=input(lbornrhi, best.)*factor;
         %end;

     convfl='Y';
   end;
%mend conversion; */ 
/*
After conversion of units it is good practice to check the dataset for outliers as they may indicate data issues in the laboratory dataset. An example of a data issue is incorrect recording of prefix ‘micro’ in the unit and using incorrect symbol ‘m’ instead of ‘u’. Unit micromole per litre should be written as ‘umol/L’ however it may be wrongly assigned as ‘mmol/L’, resulting in 1000 times higher result than the actual value. Such cases should be reported to Clinical Data Management.

Central and local laboratories
Central laboratories can be identified by a unique laboratory identifier or name/address which should be documented in a clinical data management plan, data transfer agreement, dataset specifications or similar document.

Common issues with data from local laboratories are:

missing or non‑evaluable result (for example, ‘less than 10’, ‘11-21’, ‘3 Plus’, ‘>=1000’)
upper and/or lower limit ranges not provided
non-standard/missing units or units concatenated with the result
Data obtained from a combination of central and local laboratories may also cause issues, for example:

not including results from local laboratories in the outputs
converting units only for local laboratories
applying different parameters derivations for results obtained from local and central laboratories
While central laboratories ensure a standard approach and provide values in standardised units, it is not always the case with local laboratories. The macro below may be used to separate units concatenated to the value in the result variable (i.e. unit is included in the result variable and the unit variable is missing). Macro should be called within the data step for tests where numeric result is expected. It is assumed that:

result value begins with number or ‘.’ in the case of missing result
unit value starts with a letter, the macro will not work properly for units like ‘10^9/L’ or ‘10^6/UL*/
/*condition - macro parameter, used to specify subset of tests for macro 
sepfl – flag for separated observations 
old_lborres - holds value of lborres before separation 
lborres, lborresu – standard CDISC variables, see code above */
/*
%macro separate (condition);
  if &condition. then
    do;
      lborres_=strip(lborres);
      
      if anyalpha(lborres)>0  
        and (anydigit(substr(lborres_,1 ,1 ))=1  or 
 substr(lborres_,1 ,1 )='.') 
         and missing(lborresu) then
         do;
           old_lborres=lborres;
           lborresu = substr(lborres_, anyalpha(lborres_));
           lborres = substr(lborres_, 1 , anyalpha(lborres_)-1 );
           sepfl='Y';
         end;
     end;

   drop lborres_;
%mend separate;*/

/*
Example calls may be:
%separete (lbtestcd in ('ALT' 'CA' 'BILI' 'K'))
%separate (lbcat ne 'URINALYSIS')

Assigning the baseline value
The Study Data Tabulation Model (SDTM) baseline flag should be used on team consent; otherwise it may be necessary to ask for appropriate baseline definition. Baseline definition can be a specific visit or the last non missing result prior to first dose. While developing baseline algorithm, consider usage/ imputation of measurement time or time-points, imputation of missing/ incomplete dates and inclusion of unplanned visit. Finally, is important to clarify if subjects with no baseline are expected to be summarised in post-baseline or shift tables.

How can you develop the processing of laboratory data within your organisation?

use a CDISC validator which will cover many checks described earlier
have a designated laboratory subject matter expert
develop a Best Programming Practices for Laboratory Domain document
create a database of mapping decisions from studies that use the same standard or keep one study as a reference for mapping
develop a list of standard QC checks for the laboratory domain

Develop standard macros to handle repeated steps, for example: read in and check the specification with a CDISC validator, perform the test/units mapping, read in/create codelists, convert units and derive baseline.


*/

data target.LB(drop=ERROR);
format STUDYID DOMAIN USUBJID LBSEQ LBTESTCD LBTEST LBCAT LBORRES LBORRESU LBORNRLO LBORNRHI LBSTRESC LBSTRESN LBSTRESU
       LBSTNRLO LBSTNRHI LBNRIND LBMETHOD LBBLFL LBTOX LBTOXGR VISITNUM VISIT LBDTC LBENDTC LBDY LBTPT LBTPTNUM;
set Empty_LB target.LB;
run;

**** SORT LB ACCORDING TO METADATA AND SAVE PERMANENT DATASET; 

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=LB) 

proc sort data=target.LB; 
by &LBSORTSTRING; 
run;

/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.LB file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\LB.xpt" ; 
run;


