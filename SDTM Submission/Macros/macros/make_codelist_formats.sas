*---------------------------------------------------------------*;
* make_codelist_formats.sas creates a permanent SAS format library
* stored to the libref LIBRARY from the codelist metadata file 
* CODELISTS.xls.  The permanent format library that is created
* contains formats that are named like this: 
*   CODELISTNAME_SOURCEDATASET_SOURCEVARIABLE
* where CODELISTNAME is the name of the SDTM codelist, 
* SOURCEDATASET is the name of the source SAS dataset and
* SOURCEVARIABLE is the name of the source SAS variable.
*---------------------------------------------------------------*;
%macro make_codelist_formats;

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas";


proc import 
    datafile="D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Codelists.csv"
    out=formatdata 
    dbms=csv 
    replace; 
	guessingrows=max;
run;


** make a proc format control dataset out of the SDTM metadata where original values exactly equal to CDISC Controlled Terminology;
data source.formatdata;
    set formatdata(drop=type);

	where CODELISTNAME ne "";
	/*where sourcedataset ne "" and sourcevalue ne "";*/

	keep fmtname start end label type;
	length fmtname $8 start end $ 200 label $ 200 type $ 1;

	/*fmtname = compress(codelistname || "_" || CODEDVALUE || "_" || sourcedataset 
                  || "_" || sourcevariable);*/

    fmtname = compress(codelistname);
	start = left(CODEDVALUE);
	end = left(CODEDVALUE);
	label = left(TRANSLATED);
	If compress(label) = "" then label = start;
	if upcase(sourcetype) = "NUMBER" then
	    type = "N";
	else if upcase(sourcetype) = "CHARACTER" then
	    type = "C";
run;
** make a proc format control dataset out of the SDTM metadata where original values deviate from CDISC Terminology;
data source.formatdata3;
    set formatdata(drop=type);

	where CODELISTNAME ne "" and sourcedataset ne "" and sourcevalue ne "";

	keep fmtname start end label type;
	length fmtname $80 start end $ 200 label $ 200 type $ 1;

	fmtname = compress(codelistname || "_" || sourcedataset 
                  || "_" || sourcevariable);

	start = left(sourcevalue);
	end = left(sourcevalue);
	label = left(TRANSLATED);
	If compress(label) = "" then label = left(CODEDVALUE);
	if upcase(sourcetype) = "NUMBER" then
	    type = "N";
	else if upcase(sourcetype) = "CHARACTER" then
	    type = "C";
run;

proc sort data = source.formatdata out = source.formatdata2;
by fmtname start;
run;
proc sort data = source.formatdata3 out = source.formatdata4;
by fmtname start;
run;


** create a SAS format library to be used in SDTM conversions for data values exactly equalling CDISC terminology;
proc format
    library=library
    cntlin=source.formatdata2;
run;
** create a SAS format library to be used in SDTM conversions for data values not exactly equalling CDISC terminology;
proc format
    library=library
    cntlin=source.formatdata4;
run;

proc format library=library
	cntlout=test4;
	select $Lbtest;
run;

%mend make_codelist_formats;
