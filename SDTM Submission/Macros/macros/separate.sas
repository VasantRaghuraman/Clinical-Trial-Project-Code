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
%mend separate;
