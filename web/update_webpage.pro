pro update_webpage, Exclude=exclude 
;PURPOSE:
;This procedure will sync event folders and update the webpage
;
;CATEGORY:
; AIA/General
; 
;INPUTS:
;
;
;KEYWORDS:
; 
;
;OUTPUTS:
;
;DEPENDENCIES:
;
;
;MODIFICATION HISTORY:
;Written by Alex Kendrick, 06/2014

;First update the proper webfolders

events=load_events_info()
path=getenv('CORWAV_WEB')+'events/'

if n_elements(exclude) eq 0 then begin
   for ev=0, n_elements(events)-1 do begin
      event=events[ev]
      sync_event_webfolders, event
   endfor
endif else begin
;Exlude elements listed in the exclude array
   for ev=0, n_elements(events)-1 do begin
      event=events[ev]
      for i=0, n_elements(exclude)-1 do begin
         if event.label ne exclude[i] then begin
            sync_event_webfolders, event
         endif else begin
            excludePath=path+exclude[i]
            print, excludePath
            if dir_exist(excludePath) then begin
               print, "Removing existing excluded event directory"
               spawn, 'rm -rf '+excludePath
            endif
         endelse
      endfor
   endfor
endelse

   
;Now create the website
fname='coronalwaves.content'
print, "The exclude list is:"
print, exclude
create_coronalshocks_page,path+fname,exclude=exclude


end
