%macro Drive3(dir,ext);                                                                                                                  
  %local cnt filrf rc did memcnt name; 
   %let cnt=0;          

   %let filrf=mydir;    
   %let rc=%sysfunc(filename(filrf,&dir)); 
   %let did=%sysfunc(dopen(&filrf));
    %if &did ne 0 %then %do;   
   %let memcnt=%sysfunc(dnum(&did));    

    %do i=1 %to &memcnt;              
                       
      %let name=%qscan(%qsysfunc(dread(&did,&i)),-1,.);                    
                    
      %if %qupcase(%qsysfunc(dread(&did,&i))) ne %qupcase(&name) %then %do;
       %if %superq(ext) = %superq(name) %then %do;                         
          %let cnt=%eval(&cnt+1);       
          %put %qsysfunc(dread(&did,&i));  
          proc import datafile="&dir\%qsysfunc(dread(&did,&i))" out=dsn&cnt 
           dbms=csv replace;            
          run;          
       %end; 
      %end;  

    %end;
      %end;
  %else %put &dir cannot be open.;
  %let rc=%sysfunc(dclose(&did));                                                                                                        
                                                                                                                                        
%mend Drive3;    
