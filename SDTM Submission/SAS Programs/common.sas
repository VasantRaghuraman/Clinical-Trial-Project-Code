libname library "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Formats";
libname source "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Source";
libname target "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Target";
libname original "D:\Pancrea_SanofiU_2007_134\Raw Datasets\sanofi_AVE0005_EFC10547_datasets_and readme";
libname Expsdtm "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Exportout";

filename MACRO1 "D:\Pancrea_SanofiU_2007_134\SDTM Submission\Macros\macros";

options ls=256 nocenter
        EXTENDOBSCOUNTER=NO
        mautosource 
        SASAUTOS = (MACRO1 SASAUTOS);

OPTIONS FORMCHAR="|----|+|---+=|-/\<>*";

/*options formchar = '82838485868788898A8B8C'x ;*/
