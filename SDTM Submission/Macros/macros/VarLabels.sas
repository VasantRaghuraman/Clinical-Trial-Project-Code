%macro VarLabels(Var= ,Start=1 ,NVars= ,Label= );
 %local i;
 %do i = &start %to &start + &NVars - 12;
 &var&i = "&label &i"
 %end;
%mend VarLabels;
