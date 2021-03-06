pro aia_archive_local_data_main,files,locarc,force=force
;Copy the files from the CfA to the local archive one by one, checking their filenames and putting them
;in the appropriate folders.
  nf=n_elements(files)
  cc=0
  for f=0,nf-1 do begin
     file=files[f]
     if file eq '' then continue
     tmp=strsplit(file,'AIA',/extract)
     fname='AIA'+tmp[2]
     tmm=strsplit(tmp[2],'_.',/extract)
     yy=strmid(tmm[0],0,4)
     mm=strmid(tmm[0],4,2)
     dd=strmid(tmm[0],6,2)
     hh=strmid(tmm[1],0,2)
     outpath=locarc+yy+'/'+mm+'/'+dd+'/H'+hh+'00/'

;check whether the file already was copied and skip unless forcing an overwrite.
     if file_exist(outpath+fname) and not keyword_set(force) then continue 
     cc++
     print,'Copying file '+outpath+file
     exec='cp '+file+' '+outpath
     spawn,exec  
  endfor
  if cc eq 0 then print,'       No data to update.'
  
  
end



pro aia_archive_local_data,event=event,force=force
;PURPOSE:
;Copy AIA files from the CfA archive to the user's personal
;data archive (set in the $CORWAV_DATA global variable)
;
;CATEGORY:
;AIA/General
;
;INPUTS:
;
;KEYWORDS:
;  force - if set, will overwrite existing files
; 
;OUTPUTS:
;
;DEPENDENCIES:
;aia_file_search, aia_check_dirs, aia_archive_local_data (this file)
;
;MODIFICATION HISTORY:
;Written by Kamen Kozarev, 09/23/2013   
;
  cfaarc='/Data/SDO/AIA/level1/'
  locarc=getenv('CORWAV_DATA')+'AIA_data/'
  wave=['171','193','211','335','094','131']
  
  if keyword_set(event) then events=event else events=load_events_info()
  
  for ev=0,n_elements(events)-1 do begin
     event=events[ev]
     locarc=event.aia_datapath
     print,''
     for w=0,n_elements(wave)-1 do begin
        wav=wave[w]
        print,'EVENT '+event.label+' - Copying '+wav+' channel AIA data between '+event.st+' and '+event.et
        files=aia_file_search(event.st,event.et,wav,loud=loud,missing=cfamissing,path=cfaarc)
        print,n_elements(files)
        aia_check_dirs,locarc,event.st,event.et ;check whether the local folders exist
        print,''
        aia_archive_local_data_main,files,locarc
     endfor
     print,''
  endfor
end
