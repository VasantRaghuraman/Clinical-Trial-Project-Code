%macro order_vars(max=35, list=Y X W Z);
      %global vars_in_order;
      %let no_of_vars = %sysfunc(countw(&list));
      %put no_of_vars = &no_of_vars ;

      %let vars_in_order = ;
       %do m=1 %to &max;
              %do i=1 %to &no_of_vars;
                    %let vars_in_order = &vars_in_order %scan(&list,&i)&m;
              %end;
      %end;
%mend order_vars;
