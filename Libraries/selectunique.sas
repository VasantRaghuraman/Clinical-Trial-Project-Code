libname Sanoflib "D:\Pancrea_SanofiU_2007_134\Libraries";
proc sql;
create table Sanoflib.aesort10 as 
	select * from Sanoflib.aesort9
	except
	select * from Sanoflib.aesort7;
quit;

