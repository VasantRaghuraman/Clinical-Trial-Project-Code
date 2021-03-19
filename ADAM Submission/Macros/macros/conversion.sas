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
%mend conversion; 
