%macro drive2(dir,ext,outnm);                                                                                                                  
  %local filrf rc did memcnt name i;                                                                                                    
                                                                                                                                        
  /* Assigns a fileref to the directory and opens the directory */                                                           
  %let rc=%sysfunc(filename(filrf,&dir));                                                                                               
  %let did=%sysfunc(dopen(&filrf));                                                                                                     
                                                                                                                                        
  /* Make sure directory can be open */                                                                                                 
  %if &did eq 0 %then %do;                                                                                                              
   %put Directory &dir cannot be open or does not exist;                                                                                
   %return;                                                                                                                             
  %end;
 
%global num_files;
%let num_files = %sysfunc(dnum(&did));

data &outnm; 
length fname $40;
   /* Loops through entire directory */                                                                                                 
   %do i = 1 %to %sysfunc(dnum(&did));                                                                                                  
                                                                                                                                        
     /* Retrieve name of each file */                                                                                                   
     %let name&i=%qsysfunc(dread(&did,&i));   
                                                                                                                                        
     /* Checks to see if the extension matches the parameter value */                                                                   
     /* If condition is true print the full name to the log        */                                                                   
      %if %qupcase(%qscan(&&name&i,-1,.)) = %upcase(&ext) %then %do;                                                                       
        %put &dir\&&name&i; 
        fname= "&&name&i";
		output;
      %end;                                                                                                                                                                                                                     
   %end;  
                                                                                                                                        
%end; 

%put &num_files;

run; 
                                                                                                                                        
  /* Closes the directory and clear the fileref */                                                                                      
  %let rc=%sysfunc(dclose(&did));                                                                                                       
  %let rc=%sysfunc(filename(filrf));                                                                                                    
                                                                                                                                        
%mend drive2;    
