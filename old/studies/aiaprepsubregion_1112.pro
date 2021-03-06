pro aiaprepsubregion_1112,wav;, totalData,indices,inpath,outpath=outpath,wav,date,hours,hmins,xrange,yrange,totalData,indices

;This procedure reads in a sequence of AIA fits images and saves a
;subregion as a data cube.
;!NB The user needs to know what he/she is doing...
;Kamen Kozarev, September 2010
;

;INPUTS
;inpath - basic input path for data (string)
;outpath (optional) - output path for results (string)
;date - the date, in the format [yyyy,mm,dd] (string)
;wav - wavelength of AIA channel (string)
;hours - directory name for the specific hours (string)
;hmins - search string for the right files in the format [hhm], (string)
;        where 'm' is the decimal of the minutes. For example,
;        if we want all data between 05:30 and 06:00, then set
;        hmins=['053','054','055']
;   !NB this setup of hours and hmins only works for data
;   within a single hour so far!!!
;xrange - the x-range of pixels to extract from the original data (int)
;yrange - the y-range of pixels to extract from the original data (int)

;OUTPUT
;

;OPTIONAL OUTPUT
;If the keyword outpath is set, the program saves the file 
;regionData_mmdd_wav.sav, where wav isthe wavelength of AIA 
;channel and mmdd is the month and day (for example, 
;regionData_0613_171.sav)


;===========================================================
;Constants and definitions
;===========================================================
inpath='/data/SDO/AIA/level1/'
outpath='/home/kkozarev/Desktop/AIA/limbCMEs/06132010/results/'+wav+'/'
date=['2010','11','12']
;wav='171'
hours=['H0100']
hmins=['013','014']
;xrange=[3072,4095]
;yrange=[824,1847]

dim=4096;1024
dirpath=inpath+date[0]+'/'+date[1]+'/'+date[2]+'/'

;Currently, this only works for a single hour
for h=0,n_elements(hours)-1 do begin
   for m=0,n_elements(hmins)-1 do begin
      print,dirpath+hours[h]+'/*_'+hmins[m]+'*_0'+wav+'.fits'
      if h eq 0 and m eq 0 then begin file=find_file(dirpath+hours[h]+'/*_'+hmins[m]+'*_0'+wav+'.fits')
      endif else begin
         file=[file,find_file(dirpath+hours[h]+'/*_'+hmins[m]+'*_0'+wav+'.fits')]
      endelse
   endfor
endfor

nfiles=n_elements(file)
print,nfiles
totalData=intarr(nfiles,dim,dim)

times=strarr(nfiles)

read_sdo,file[0],index,data
indices=replicate(index,nfiles)
;===========================================================


;===========================================================
;2. Load the files
;===========================================================
for i=0,nfiles-1 do begin
   ;mreadfits,file[i],index,data
   read_sdo,file[i],index,data
   ;data=congrid(data,1024,1024)
   ;tmp1=data[xrange[0]:xrange[1],yrange[0]:yrange[1]]
   totalData[i,*,*]=data;tmp1
   copy_struct_inx,index,indices,index_to=i
   print,'Read frame #'+strtrim(string(i+1),2)+' out of '+strtrim(string(nfiles),2)
   times[i]=index.date_obs
endfor
;===========================================================

;avg=totaldata[0,*,*]
;for i=1,9 do avg=avg+totaldata[i,*,*]
;avg=avg/10

;stop

;===========================================================
;3. Save all the data so I can go back and change the profiles
if keyword_set(outpath) then begin
   save,totalData,indices,times,filename=outpath+'regionData_'+date[1]+date[2]+'_'+wav+'.sav'
   endif
;===========================================================

end
