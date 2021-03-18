/***********************************************************************************************
Project: Pancrea_SanofiU_2007_134
Program: AE
Programmers: Vasant Raghuraman
Date: March 13, 2019
Project: Practice Project in Oncology
Raw Dataset: Origin.AE
************************************************************************************************/

%include "D:\Pancrea_SanofiU_2007_134\SDTM Submission\SAS Programs\common.sas" /source2;

%make_codelist_formats

/*Make Empty_AE Dataset from metadata*/

%make_empty_dataset(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=AE)

/* To test the proper dates we consider day 1 for all subjects as June 30, 2013 which 1s 19539*/

/*Since FAAE dataset has already extracted VISITNUM from SV domain, we shall use the same dataset here
to merge with Original.AE dataset*/

data source.ae1a;
set source.FAAE2D;
run;

/*Capturing data from suplied source dataset*/

data source.ae1b;
set Original.ae(rename=(RUSUBJID=USUBJID));
AEDICTVS="Meddra21.1";
AETERM=AELLT;
run;

proc sql;
create table source.ae1c as
select ae1b.STUDYID, ae1b.DOMAIN,ae1b.AESEQ, ae1b.AESPID, ae1b.AEREFID, ae1b.AEDECOD, ae1b.AEBODSYS, ae1b.AESER, 
       ae1b.AEACN, ae1b.AEREL, ae1b.AEPATT, ae1b.AEOUT, ae1b.AESOD, 
       ae1b.AECONTRT, ae1b.AESCONG, ae1b.AESDISAB, ae1b.AESDTH, ae1b.AESHOSP, ae1b.AESLIFE, ae1b.AESMIE, ae1b.AETOXGR, 
       ae1a.VISITNUM, ae1a.VISIT, ae1b.AESTDY, ae1b.AEENDY, ae1b.AEDUR,
	   ae1b.AEACCOL, ae1b.AEDICTVS, ae1b.AEDURU, ae1b.AEHLGT, ae1b.AEHLT, ae1b.AELLT, ae1b.AEORDER, ae1b.AEOUTCOL, 
       ae1b.AEPREG, ae1b.AETRTEM,ae1b.AESERDY, ae1b.AEDTHWK, ae1b.AESTWK,ae1b.AESERWK, ae1b.RSUBJID, ae1b.USUBJID, ae1b.AETERM
from source.ae1b as ae1b
left join
source.ae1a as ae1a
on ae1a.USUBJID=ae1b.USUBJID and ae1b.AESEQ=ae1a.AESEQ;
quit;





/*Importing raw dataset to capture information*/
proc import 
        datafile="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\AEReport.csv"
        out=source.AEReport
        dbms=csv
        replace;
		guessingrows=max;
run;

/*Joining raw dataset to Meddra 21.1 Controlled Terminology for Adverse Event*/

proc sql;
create table source.ae2 as
select * from source.AE1C as AE1
left join
source.AEReport as AEReport
on AE1.AETERM = AEReport.sourcevalue
order by USUBJID, VISITNUM, AESTDY;
quit;

/*Since the records are organized in a manner that there are multiple records with multiple visits for the same AE
we select single recors per AE with summary records “collapsed” to the highest level of severity, causality, 
seriousness,the final outcome etc. Remainder of the information will be part of the FA and SQFAAE domain*/

proc sort data = source.AE2 out=Source.AE2A;
by USUBJID AELLT AEPATT VISITNUM;
run;

data source.AE2B;
format USUBJID AELLT AEPATT GROUPID AEGRPID AESEQ VISITNUM VISIT;
set source.AE2A;
if AEPATT="NEW" then GROUPID+1;
run;

data source.ae3(drop= AEPATT AEPATTnum AESEQ VISITNUM VISIT AESPID AEREFID AESER AEACN AEACNnum AEREL AERELnum 
                      AEOUT AEOUTnum AESOD AESODnum AECONTRT AECONTRTnum AESCONG AESCONGnum AESDISAB AESDISABnum
					  AESDTH AESDTHnum AESHOSP AESHOSPnum AESLIFE AESLIFEnum AESMIE AESMIEnum AETOXGR AESTDY AEENDY AEDUR
                      AEACCOL AEACCOLnum AELLT AEDECOD AEBODSYS AEHLGT AEHLT AEORDER sourcedataset sourcevariable
                      sourcevalue sourcetype AEOUTCOL AEOUTCOLnum AEPREG AEPREGnum AETRTEM AETRTEMnum AESERDY AEDTHWK 
                      AESTWK AESERWK RSUBJID AEPATTnewnum AESERnewnum AEACNnewnum AERELnewnum AEOUTnewnum AECONTRTnewnum
                      AESCONGnewnum AESDISABnewnum AESDTHnewnum AESHOSPnewnum AEPREGnewnum AESLIFEnewnum AESMIEnewnum
                      AEACCOLnewnum AEOUTCOLnewnum AETRTEMnewnum AESODnewnum AESERnum);

format USUBJID GROUPID AESEQnew AEPATTnew VISITNUMmin VISITnummax VISITmin VISITmax AESPIDnew AEREFIDnew 
       AESERnew AEACNnew AERELnew AESODnew AECONTRTnew AESCONGnew AESDISABnew AESDTHnewnum AESDTHnew AESHOSPnew 
       AEPREGnew AESLIFEnew AESMIEnew AETOXGRnew AESTDYnew AEENDYnew AEDURnew AEACCOLnew AEDURU AEOUTnew AEOUTCOLnew 
       AEPREGnew AETRTEMnew AESERDYnew AEDTHwknew AESTWKnew AESERwknew;

set source.AE2B;
by USUBJID GROUPID;

retain AESEQnew AEPATTnew AEPATTnewnum VISITNUMmin VISITNUMmax VISITmin VISITmax AESPIDnew AEREFIDnew AESERnewnum AESERnew AEACNnewnum 
       AEACNnew AERELnewnum AERELnew AEOUTnewnum AEOUTnew AESODnewnum AESODnew AECONTRTnewnum AECONTRTnew 
       AESCONGnewnum AESCONGnew AESDISABnewnum AESDISABnew AESDTHnewnum AESDTHnew AESHOSPnewnum AESHOSPnew 
       AEPREGnewnum AEPREGnew AESLIFEnewnum AESLIFEnew AESMIEnewnum AESMIEnew AETOXGRnew AESTDYnew AEENDYnew
       AEDURnew AEACCOLnewnum AEACCOLnew AEDURU AEOUTCOLnewnum AEOUTCOLnew AEPREGnewnum AEPREGnew AETRTEMnewnum AETRTEMnew
       AESERDYnew AEDTHwknew AESTWKnew AESERwknew;

if first.GROUPID then do;

        if AEPATT = "NEW" then AEPATTnum=1;
		else AEPATTnum=2;
		AEPATTnewnum=AEPATTnum;
		AEPATTnew=AEPATT;

if first.USUBJID then AESEQnew=1; else AESEQnew=AESEQnew+1;

        VISITNUMmin=VISITNUM;
		VISITNUMmax=VISITNUM;	
        VISITmin=VISIT;
        VISITmax=VISIT;	
        AESPIDnew=AESPID;
		AEREFIDnew=AEREFID;		

        if AESER ="Y" then AESERnum=1;
		else AESERnum=2;
		AESERnewnum = AESERnum;
		AESERnew=AESER;
				
		if AEACN="DOSE NOT CHANGED" then AEACNnum=1;
		if AEACN="DOSE REDUCED" then AEACNnum=2;
		if AEACN="DRUG WITHDRAWN" then AEACNnum=3;
        AEACNnewnum=AEACNnum;
		AEACNnew=AEACN;
       
        if AEREL ="Y" then AERELnum=1;
		else AERELnum=2;
		AERELnewnum = AERELnum;
        AERELnew=AEREL;

        if AEOUT="UNKNOWN" then AEOUTnum=1;
        if AEOUT="RECOVERING/RESOLVING" then AEOUTnum=2;
		if AEOUT="NOT RECOVERED/NOT RESOLVED" then AEOUTnum=3;
		if AEOUT="RECOVERED/RESOLVED WITH SEQUELAE" then AEOUTnum=4;
		if AEOUT="RECOVERED/RESOLVED" then AEOUTnum=5;
		if AEOUT="FATAL" then AEOUTnum=6;
		AEOUTnewnum=AEOUTnum;
		AEOUTnew=AEOUT;	     

        if AESOD ="Y" then AESODnum=1;
		else AESODnum=2;
		AESODnewnum = AESODnum;
        AESODnew=AESOD;

		if AECONTRT ="Y" then AECONTRTnum=1;
		else AECONTRTnum=2;
		AECONTRTnewnum=AECONTRTnum;
		AECONTRTnew=AECONTRT;

		if AESCONG = "Y" then AESCONGnum=1;
		else AESCONGnum=2;
		AESCONGnewnum=AESCONGnum;
		AESCONGnew=AESCONG;

		if AESDISAB = "Y" then AESDISABnum=1;
        else AESDISABnum=2;
		AESDISABnewnum=AESDISABnum;
		AESDISABnew=AESDISAB;

		if AESDTH = "Y" then AESDTHnum=1;
		else AESDTHnum=2;
		AESDTHnewnum=AESDTHnum;
		AESDTHnew=AESDTH;

		if AESHOSP ="Y" then AESHOSPnum=1;
		else AESHOSPnum=2;
        AESHOSPnewnum=AESHOSPnum;
		AESHOSPnew=AESHOSP;

		if AESLIFE ="Y" then AESLIFEnum=1;
		else AESLIFEnum=2;
        AESLIFEnewnum=AESLIFEnum;
		AESLIFEnew=AESLIFE;

		if AESMIE ="Y" then AESMIEnum=1;
		else AESMIEnum=2;
        AESMIEnewnum=AESMIEnum;
		AESMIEnew=AESMIE;

		AETOXGRnew=input(AETOXGR,3.);
		AESTDYnew=AESTDY;		
        AEENDYnew=AEENDY;
		AEDURnew=input(AEDUR,8.);		

		if AEACCOL="NONE" then AEACCOLnum=1;
        if AEACCOL="DELAYED" then AEACCOLnum=2;
		if AEACCOL="DOSE REDUCED" then AEACCOLnum=3;
		if AEACCOL="DELAYED AND REDUCED" then AEACCOLnum=4;
		if AEACCOL="PERMANENTLY DISCONTINUED" then AEACCOLnum=5;
        AEACCOLnewnum=AEACCOLnum;
		AEACCOLnew=AEACCOL;

		format AEDURU UNIT.;	

		if AEOUTCOL="UNKNOWN" then AEOUTCOLnum=1;
        if AEOUTCOL="RECOVERING/RESOLVING" then AEOUTCOLnum=2;
		if AEOUTCOL="NOT RECOVERED/NOT RESOLVED" then AEOUTCOLnum=3;
		if AEOUTCOL="NOT RECOVERED/NOT RESOLVED" then AEOUTCOLnum=3;
		if AEOUTCOL="RECOVERED/RESOLVED" then AEOUTCOLnum=4;
		if AEOUTCOL="FATAL" then AEOUTCOLnum=5;
		AEOUTCOLnewnum=AEOUTCOLnum;
		AEOUTCOLnew=AEOUTCOL;	

		if AEPREG ="Y" then AEPREGnum=1;
		else AEPREGnum=2;
		AEPREGnewnum=AEPREGnum;
		AEPREGnew=AEPREG;

        if AETRTEM ="T" then AETRTEMnum=1;
		else AETRTEMnum=2;
		AETRTEMnewnum=AETRTEMnum;
		AETRTEMnew=AETRTEM;


        AESERDYnew=AESERDY;
		AEDTHWKnew=AEDTHwk;		AESTWKnew=AESTWK;
        AESERWKnew=AESERwk;	
end;


/**********************************************************************************************************************/



if not(first.GROUPID) then do;

/*Encode AEPATT Controlled Terminology to numeric values and get the highest level of severity start*/

        if AEPATT = "NEW" then AEPATTnum=1;
		else AEPATTnum=2;

		AEPATTnewnum=min(AEPATTnum,AEPATTnewnum);

		if AEPATTnewnum=1 then AEPATTnew="NEW";
		else AEPATTnew="ERROR";

/*Encode AEPATT Controlled Terminology to numeric values and get the highest level of severity end*/

		
		VISITNUMmin=min(VISITnum,VISITNUMmin);
		if VISITNUMmin=VISITnum then VISITmin=VISIT;

	
		VISITNUMmax=max(VISITnum,VISITNUMmax);
		if VISITNUMmax=VISITNUM then VISITmax=VISIT;

		
/*Encode AESER Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESER ="Y" then AESERnum=1;
		else AESERnum=2;

        AESERnewnum=min(AESERnum,AESERnewnum);
        
		if AESERnewnum=1 then AESERnew="Y";
		else AESERnew="N";
		
/*Encode AESER Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AEACN Controlled Terminology to numeric values and get the highest level of severity start*/
		if AEACN="DOSE NOT CHANGED" then AEACNnum=1;
		if AEACN="DOSE REDUCED" then AEACNnum=2;
		if AEACN="DRUG WITHDRAWN" then AEACNnum=3;

		AEACNnewnum=max(AEACNnewnum,AEACNnum);

        if AEACNnewnum=1 then  AEACNnew="DOSE NOT CHANGED";
		if AEACNnewnum=2 then  AEACNnew="DOSE REDUCED";
		if AEACNnewnum=3 then  AEACNnew="DRUG WITHDRAWN";

/*Encode AEACN Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AEREL Controlled Terminology to numeric values and get the highest level of severity start*/

        if AEREL ="Y" then AERELnum=1;
		else AERELnum=2;

        AERELnewnum=min(AERELnum,AERELnewnum);
        
		if AERELnewnum=1 then AERELnew="Y";
		else AERELnew="N";
		
/*Encode AEREL Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AEOUT Controlled Terminology to numeric values and get the highest level of severity start*/

		if AEOUT="UNKNOWN" then AEOUTnum=1;
        if AEOUT="RECOVERING/RESOLVING" then AEOUTnum=2;
		if AEOUT="NOT RECOVERED/NOT RESOLVED" then AEOUTnum=3;
		if AEOUT="RECOVERED/RESOLVED WITH SEQUELAE" then AEOUTnum=4;
		if AEOUT="RECOVERED/RESOLVED" then AEOUTnum=5;
		if AEOUT="FATAL" then AEOUTnum=6;

		AEOUTnewnum=max(AEOUTnewnum,AEOUTnum);
        
		if AEOUTnewnum=1 then AEOUTnew="UNKNOWN";
		if AEOUTnewnum=2 then AEOUTnew="RECOVERING/RESOLVING";
		if AEOUTnewnum=3 then AEOUTnew="NOT RECOVERED/NOT RESOLVED";
		if AEOUTnewnum=4 then AEOUTnew="RECOVERED/RESOLVED WITH SEQUELAE";
		if AEOUTnewnum=5 then AEOUTnew="RECOVERED/RESOLVED";
		if AEOUTnewnum=6 then AEOUTnew="FATAL";
        
/*Encode AEOUT Controlled Terminology to numeric values and get the highest level of severity end*/	
		
/*Encode AESOD Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESOD ="Y" then AESODnum=1;
		else AESODnum=2;

        AESODnewnum=min(AESODnum,AESODnewnum);
        
		if AESODnewnum=1 then AESODnew="Y";
		else AESODnew="N";
		
/*Encode AESOD Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AECONTRT Controlled Terminology to numeric values and get the highest level of severity start*/

        if AECONTRT ="Y" then AECONTRTnum=1;
		else AECONTRTnum=2;

        AECONTRTnewnum=min(AECONTRTnum,AECONTRTnewnum);
        
		if AECONTRTnewnum=1 then AECONTRTnew="Y";
		else AECONTRTnew="N";
		
/*Encode AECONTRT Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AESCONG Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESCONG ="Y" then AESCONGnum=1;
		else AESCONGnum=2;

        AESCONGnewnum=min(AESCONGnum,AESCONGnewnum);
        
		if AESCONGnewnum=1 then AESCONGnew="Y";
		else AESCONGnew="";
		
/*Encode AESCONG Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AESDISAB Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESDISAB ="Y" then AESDISABnum=1;
		else AESDISABnum=2;

        AESDISABnewnum=min(AESDISABnum,AESDISABnewnum);
        
		if AESDISABnewnum=1 then AESDISABnew="Y";
		else AESDISABnew="";
		
/*Encode AESDISAB Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AESDTH Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESDTH ="Y" then AESDTHnum=1;
		else AESDTHnum=2;

        AESDTHnewnum=min(AESDTHnum,AESDTHnewnum);
        
		if AESDTHnewnum=1 then AESDTHnew="Y";
		else AESDTHnew="";
		
/*Encode AESDTH Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AESHOSP Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESHOSP ="Y" then AESHOSPnum=1;
		else AESHOSPnum=2;

        AESHOSPnewnum=min(AESHOSPnum,AESHOSPnewnum);
        
		if AESHOSPnewnum=1 then AESHOSPnew="Y";
		else AESHOSPnew="";
		
/*Encode AESHOSP Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AESLIFE Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESLIFE ="Y" then AESLIFEnum=1;
		else AESLIFEnum=2;

        AESLIFEnewnum=min(AESLIFEnum,AESLIFEnewnum);
        
		if AESLIFEnewnum=1 then AESLIFEnew="Y";
		else AESLIFEnew="";
		
/*Encode AESLIFE Controlled Terminology to numeric values and get the highest level of severity end*/


/*Encode AESMIE Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESMIE ="Y" then AESMIEnum=1;
		else AESMIEnum=2;

        AESMIEnewnum=min(AESMIEnum,AESMIEnewnum);
        
		if AESMIEnewnum=1 then AESMIEnew="Y";
		else AESMIEnew="";
		
/*Encode AESMIE Controlled Terminology to numeric values and get the highest level of severity end*/
	
		
		AETOXGRnew=max(input(AETOXGR,3.),AETOXGRnew);
		AEENDYnew=max(AEENDY,AEENDYnew);
		if AESTDY ne . then AESTDYnew=min(AESTDY,AESTDYnew);
        AEDURnew=AEDURnew+input(AEDUR,8.);

/*Encode AEACCOL Controlled Terminology to numeric values and get the highest level of severity start*/

        if AEACCOL="NONE" then AEACCOLnum=1;
        if AEACCOL="DELAYED" then AEACCOLnum=2;
		if AEACCOL="DOSE REDUCED" then AEACCOLnum=3;
		if AEACCOL="DELAYED AND REDUCED" then AEACCOLnum=4;
		if AEACCOL="PERMANENTLY DISCONTINUED" then AEACCOLnum=5;

        AEACCOLnewnum=max(AEACCOLnum,AEACCOLnewnum);

		if AEACCOLnewnum=1 then AEACCOLnew="NONE";
		if AEACCOLnewnum=2 then AEACCOLnew="DELAYED";
		if AEACCOLnewnum=3 then AEACCOLnew="DOSE REDUCED";
		if AEACCOLnewnum=4 then AEACCOLnew="DELAYED AND REDUCED";
		if AEACCOLnewnum=5 then AEACCOLnew="PERMANENTLY DISCONTINUED";

/*Encode AEACCOL Controlled Terminology to numeric values and get the highest level of severity end*/

        format AEDURU UNIT.;

/*Encode AEOUTCOL Controlled Terminology to numeric values and get the highest level of severity start*/

        if AEOUTCOL="UNKNOWN" then AEOUTCOLnum=1;
        if AEOUTCOL="RECOVERING/RESOLVING" then AEOUTCOLnum=2;
		if AEOUTCOL="NOT RECOVERED/NOT RESOLVED" then AEOUTCOLnum=3;
		if AEOUTCOL="NOT RECOVERED/NOT RESOLVED" then AEOUTCOLnum=3;
		if AEOUTCOL="RECOVERED/RESOLVED" then AEOUTCOLnum=4;
		if AEOUTCOL="FATAL" then AEOUTCOLnum=5;

		AEOUTCOLnewnum=max(AEOUTCOLnum,AEOUTCOLnewnum);

		if AEOUTCOLnewnum=1 then AEOUTCOLnew="UNKNOWN";
        if AEOUTCOLnewnum=2 then AEOUTCOLnew="RECOVERING/RESOLVING";
		if AEOUTCOLnewnum=3 then AEOUTCOLnew="NOT RECOVERED/NOT RESOLVED";
		if AEOUTCOLnewnum=3 then AEOUTCOLnew="NOT RECOVERED/NOT RESOLVED";
        if AEOUTCOLnewnum=4 then AEOUTCOLnew="RECOVERED/RESOLVED";
        if AEOUTCOLnewnum=5 then AEOUTCOLnew="FATAL";
		
/*Encode AEOUTCOL Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AEPREG Controlled Terminology to numeric values and get the highest level of severity start*/

        if AEPREG ="Y" then AEPREGnum=1;
		else AEPREGnum=2;

        AEPREGnewnum=min(AEPREGnum,AEPREGnewnum);
        
		if AEPREGnum=1 then AEPREGnew="Y";
		else AEPREGnew="N";
		
/*Encode AEPREG Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AETRTEM Controlled Terminology to numeric values and get the highest level of severity start*/

        if AETRTEM ="T" then AETRTEMnum=1;
		else AETRTEMnum=2;

        AETRTEMnewnum=min(AETRTEMnum,AETRTEMnewnum);
        
		if AETRTEMnewnum=1 then AETRTEMnew="T";
		else AEPREGnew="";
		
/*Encode AETRTEM Controlled Terminology to numeric values and get the highest level of severity end*/


/*Encode AESHOSP Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESHOSP ="Y" then AESHOSPnum=1;
		else AESHOSPnum=2;

        AESHOSPnewnum=max(AESHOSPnum,AESHOSPnewnum);
        
		if AESHOSPnewnum=1 then AESHOSPnew="Y";
		if AESHOSPnewnum=2 then AESHOSPnew="";
		
/*Encode AESHOSP Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AESLIFE Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESLIFE ="Y" then AESLIFEnum=1;
		else AESLIFEnum=2;

        AESLIFEnewnum=max(AESLIFEnum,AESLIFEnewnum);
        
		if AESLIFEnewnum=1 then AESLIFEnew="Y";
		if AESLIFEnewnum=2 then AESLIFEnew="";
		
/*Encode AESLIFE Controlled Terminology to numeric values and get the highest level of severity end*/

/*Encode AESMIE Controlled Terminology to numeric values and get the highest level of severity start*/

        if AESMIE ="Y" then AESMIEnum=1;
		else AESMIEnum=2;

        AESMIEnewnum=max(AESMIEnum,AESMIEnewnum);
        
		if AESMIEnewnum=1 then AESMIEnew="Y";
		if AESMIEnewnum=2 then AESMIEnew="";
		
/*Encode AESMIE Controlled Terminology to numeric values and get the highest level of severity end*/
		
		if AESERDY ne . then AESERDYnew=min(AESERDY,AESERDYnew);
		if AEDTHWK ne . then AEDTHWKnew=max(AEDTHWK,AEDTHWKnew);
		if AESTWK ne . then AESTWKnew=min(AESTWK,AESTWKnew);
		if AESERWK ne . then AESERWKnew=min(AESERWK,AESERWKnew);
		
end;

if last.GROUPID;
run;


/*Create table with variables as per STDM AE dataset requirements for naming with the extra variables*/

data source.ae4(drop= AESEQnew AEREFIDnew AESPIDnew GROUPID AEACNnew AESERnew AERELnew AESODnew AECONTRTnew AESCONGnew AESDISABnew AESDTHnew
                      Lowest_Level_Term Lowest_Level_Term_Code Preferred_Term Preferred_Term_Code High_Level_Term High_Level_Term_Code 
                      High_Level_Group_Term High_Level_Group_Term_Code Body_System_Or_Organ_Class Boody_System_Or_Organ_Class_Code
                      AESDISABnewnum AEPATTnew AESHOSPnew AEPREGnew AESLIFEnew AESMIEnew AETOXGRnew AESTDYnew
                      AEENDYnew AEDURnew AEACCOLnew AEDURnew AEOUTCOLnew AEOUTnew AETRTEMnew AESERDYnew AEDTHwknew AESTWKnew
					  AESERwknew);
format STUDYID DOMAIN USUBJID AESEQ AEREFID AESPID AETERM AELLT AELLTCD AEDECOD AEPTCD AEHLT AEHLTCD AEHLGT AEHLGTCD 
       AEBODSYS AEBDSYCD AESOC AESOCCD AESER AEACN AEREL AEPATT AEOUT AESCONG AESDISAB AESDTH AEENTPT TAETORD;

set source.ae3;

AESEQ=AESEQnew; AEREFID=AEREFIDnew;
AESPID=AESPIDnew; AELLT=Lowest_Level_Term;
AELLTCD=Lowest_Level_Term_Code; AEDECOD=Preferred_Term;
AEPTCD=Preferred_Term_Code; AEHLT=High_Level_Term;
AEHLTCD=High_Level_Term_Code; AEHLGT=High_Level_Group_Term;
AEHLGTCD=High_Level_Group_Term_Code; AEBODSYS=Body_System_Or_Organ_Class;
AEBDSYCD=Boody_System_Or_Organ_Class_Code; AESOC=Body_System_Or_Organ_Class;
AESOCCD=Boody_System_Or_Organ_Class_Code; AEACN=AEACNnew;
AEENTPT=VISITmax; AESER=AESERnew;
AEENTPT=put(AEENTPT,$VISIT.);
AEREL=AERELnew; AEPATT=AEPATTnew;
AEOUT=AEOUTnew; AESCONG=AESCONGnew;
AESDISAB=AESDISABnew; AESDTH=AESDTHnew;
AESHOSP=AESHOSPnew; AEPREG=AEPREGnew;
AESLIFE=AESLIFEnew; AESMIE=AESMIEnew;
AETOXGR=put(AETOXGRnew,3.); AESTDY=AESTDYnew;
AEENDY=AEENDYnew; AEDUR=put(AEDURnew,8.);
AEACCOL=AEACCOLnew; AEOUT=AEOUTnew;
AEOUTCOL=AEOUTCOLnew; AETRTEM=AETRTEMnew;
AESERDY=AESERDYnew; AEDTHwk=AEDTHWKnew;
AESTWK=AESTWKnew; AESERwk=AESERwknew;
AESOD=AESODnew; AECONTRT=AECONTRTnew;
if VISITNUMmin<80 then TAETORD=VISITNUMmin+1;
else TAETORD=VISITNUMmin-59;
run;

proc sql;
create table source.ae4a as
select ae4.*,RFST.RFSTDT
from source.ae4 as ae4
left join
source.RFSTDTFIN as RFST
on ae4.USUBJID=RFST.USUBJID;
quit;



data source.ae5(Drop= AESERDY AEDTHwk AESTWK AESERwk VISITNUMmin VISITNUMmax VISITmin VISITmax AEDURU AEDICTVS
                AEPREG AEACCOL AEOUTCOL AETRTEM AEDUR RFSTDT);
format STUDYID DOMAIN USUBJID AESEQ AEREFID AESPID AETERM AELLT AELLTCD AEDECOD AEPTCD AEHLT AEHLTCD AEHLGT AEHLGTCD
       AEBODSYS AEBDSYCD AESOC AESOCCD AESER AEACN AEREL AEPATT AEOUT AESCONG AESDISAB AESDTH AESHOSP AESLIFE AESOD AESMIE
	   AECONTRT AETOXGR AESTDTC AEENDTC AESTDY AEENDY AEENTPT TAETORD; 
set source.ae4a;

if AESTDY ne . then do;
if AESTDY>0 then AESTDT=RFSTDT+AESTDY-1;
if AESTDY<0 then AESTDT=RFSTDT+AESTDY;
end;
else AESTDT = .;

if AEENDY ne . then do;
if AEENDY>0 then AEENDT=RFSTDT+AEENDT-1;
if AEENDY<0 then AEENDT=RFSTDT+AEENDT;
end;
else AEENDT = .;

AESTDTC="";
AEENDTC="";

AEACN=put(AEACN,$ACN.);
AEOUT=put(AEOUT,$OUT.);

run;

proc sql;
create table source.ae5a as
select ae5.STUDYID, ae5.DOMAIN, ae5.USUBJID, ae5.AESEQ, ae5.AEREFID, ae5.AESPID, ae5.AETERM, ae5.AELLT, ae5.AELLTCD,
       ae5.AEDECOD, ae5.AEPTCD, ae5.AEHLT, ae5.AEHLTCD, ae5.AEHLGT, ae5.AEHLGTCD,
       ae5.AEBODSYS, ae5.AEBDSYCD, ae5.AESOC, ae5.AESOCCD, ae5.AESER, ae5.AEACN, ae5.AEREL, ae5.AEPATT, 
       ae5.AEOUT, ae5.AESCONG, ae5.AESDISAB, ae5.AESDTH, ae5.AESHOSP, ae5.AESLIFE, ae5.AESOD, ae5.AESMIE,
	   ae5.AECONTRT, ae5.AETOXGR, ae5.AESTDTC, ae5.AEENDTC, ae5.AESTDY, ae5.AEENDY, ae5.TAETORD,
	   TA.EPOCH as EPOCH
from source.ae5 as ae5
left join
target.ta as TA
on ae5.TAETORD=TA.TAETORD and TA.ARMCD contains "PLACEBO"
order by USUBJID,AESEQ;
quit;



/*Try to extract all variable names in ae5a to ae6 to help create format statement below*/
proc transpose data = source.ae5a(obs=0) out=source.ae6;
var _all_;
run;

proc sql noprint;
 select _NAME_ into : list separated by ' '
  from source.ae6;
quit;

data _null_;
%put &list;
run;

/*Try to extract all variable names in ae1 to ae7 to help create format statement below*/
proc transpose data = source.ae1(obs=0) out=source.ae7;
var _all_;
run;

proc sql noprint;
 select _NAME_ into : list separated by ' '
  from source.ae7;
quit;

data _null_;
%put &list;
run;


/*Compare all the variables of AE according to variables in ae7 to ae4 to see which variables need to be removed to create AE dataset*/

proc sql;
create table source.ae8 as
select _NAME_ from source.ae7
except 
select _NAME_ from source.ae6;
quit;

proc sql noprint;
 select _NAME_ into : list separated by ' '
  from source.ae8;
quit;

data _null_;
%put &list;
run;

/*Transfer FA variables to Excel file to input metadata*/
PROC EXPORT DATA= SOURCE.ae8 
            OUTFILE= "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Excel Files\ae8.csv" 
            DBMS=CSV LABEL REPLACE;
     PUTNAMES=YES;
RUN;

/*Populate Empty target dataset and with attributes from metadata and populate*/
data target.AE;
set EMPTY_AE source.ae5a;
run;

**** SORT AE ACCORDING TO METADATA AND SAVE PERMANENT DATASET;

%make_sort_order(metadatafile=D:\Pancrea_SanofiU_2007_134\SDTM and Adam Metadata\Variable.csv,dataset=AE) 

proc sort data=target.AE; 
by &AESORTSTRING; 
run;

data source.ae1;
set source.ae4;
label AETRTEM="Treatment Emergent Classification" AEPREG="Occurred with Pregnancy";
run;

/*Create SuppAE Domain*/

%SUPPDOMAIN(dmname=AE)


/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.AE file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\AE.xpt" ; 
run;


/*Create SAS Export files for all the Target SAS Datasets*/
proc cport data=target.SUPPAE file="D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout\SUPPAE.xpt" ; 
run;
