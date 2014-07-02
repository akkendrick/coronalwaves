pro test_pfss_return_field
;Test the procedure pfss_return_field

;You can run for one event, like this.
  one=1
  if one eq 1 then begin
     event=load_events_info(label='130517_01')
     date=event.st
     aia_carrington_latlon,event,lat,lon
     aclon=lon+event.arlon
     aclat=lat+event.arlat
     box=[aclon-90.,aclat-90.,aclon+90.,aclat+90.]
     ;box=[aclon-45.,aclat-45.,aclon+45.,aclat+45.]
     
     pfss_return_field,date,invdens=0.5,/save,event=event;,box=box
     ;pfss_return_field,date,invdens=8,/save,path=event.pfsspath,event=event;,box=box
  endif
  
  
;Alternatively, run for all events
  all=0
  if all eq 1 then begin
     events=load_events_info()
     for ev=0,n_elements(events)-1 do begin
        event=events[ev]
        date=event.st
        pfss_return_field,date,invdens=1,/save,path=event.pfsspath,event=event
     endfor
  endif



end

pro pfss_return_field,date,event=event,rstart=rstart,invdens=invdens,pfss_struct=pfss_struct,save=save,path=path,box=box
;PURPOSE:
; Return the PFSS field model
;CATEGORY:
; PFSS
;
;INPUTS:
;
;KEYWORDS:
;        BOX - 
;        SAVE -
;        
;
;OUTPUTS:
;
; 
;DEPENDENCIES:
;pfss_restore, pfss_field_start_coord, pfss_trace_field,
;pfss_to_spherical, 
;
;MODIFICATION HISTORY:
;Written by Kamen Kozarev, 2011 (based on the pfss_example_1.pro file)
;Modified by Kamen Kozarev, 02/21/2014 - added the box keyword to
;                                        reduce the extent of the PFSS
;                                        model coverage
;


;date='2011-01-25'
;/Users/kkozarev/AIA/algoTests/yaftawave/normalized_AIA_20110125_05_193_subdata.sav
;Set up the common block variables
@pfss_data_block
;stop
;spherical_to_pfss,pfssData
  if n_elements(date) eq 0 then begin
     print,'You need to supply a date string, like "2011-01-25"'
     return
  endif
;Restore B-field model
  pfss_restore,pfss_time2file(date,/ssw_cat,/url)

;Set the save path
if not keyword_set(path) then path=event.pfsspath  
;  starting points to be on a regular grid covering the full disk,
;  with a starting radius of r=1.00 Rsun
  if not keyword_set (rstart) then rstart=1.05
;  factor inverse to line density, i.e. lower values = more lines
  if not keyword_set(invdens) then invdens = 4 
  if keyword_set(box) then $
     pfss_field_start_coord,5,invdens,radstart=rstart,bbox=box $
  else $
     pfss_field_start_coord,5,invdens,radstart=rstart
  
;stop

;  trace the field lines passing through the starting point arrays
  pfss_trace_field, kind
;@pfss_data_block
  ind=where(ptph lt 0.0)
  if ind[0] gt -1 then ptph[ind]+=2*!PI
  ind=where(ptph ge 2*!PI)
  if ind[0] gt -1 then ptph[ind]-=2*!PI
  ind=where(ptth lt 0.0)
  if ind[0] gt -1 then ptth[ind]+=2*!PI
  ind=where(ptth ge 2*!PI)
  if ind[0] gt -1 then ptth[ind]-=2*!PI
;Create a structure to hold the results. The data are in 
;(r,theta,phi) spherical/heliographic coordinate system:
;r is the distance away from sun-center in units of solar
;      radii, such that valid values are between 1 (the nominal
;      photosphere and 2.5 (the radius of the source surface).
;      theta and phi are respectively the colatitude and
;      longitude in radians.
  pfss_to_spherical,sph_data
  if keyword_set(pfss_struct) then pfss_struct=sph_data
  
;pfss_data is a structure array of type
;{spherical_field_data, $
;  br:ptr_new(),bth:ptr_new(),bph:ptr_new(),bderivs:ptr_new(),$
;  nr:-1l,nlat:-1l,nlon:-1l,$
;  rix:ptr_new(),theta:ptr_new(),phi:ptr_new(),lat:ptr_new(),lon:ptr_new(),$
;  lonbounds:[-1d,-1d],str:ptr_new(),stth:ptr_new(),stph:ptr_new(),$
;  ptr:ptr_new(),ptth:ptr_new(),ptph:ptr_new(),nstep:ptr_new(),$
;  extra_objects:ptr_new()}
;      The three arrays ptr,ptth,ptph contain the coordinates of
;      all N field lines that have been traced.  Since the field
;      lines can be of arbitrary length, the array nstep contains
;      the number of points needed to define the Nth field line.
;      Thus, field line i (where i is between 0 and N-1) is
;      represented by the points ptr(0:nstep(i)-1,i), and likewise
;      for ptth and ptph.
  
;Get the Carrington coordinates. Returns an array [R,lon,lat] at
;specified time.
;Note: AIA's index already has the carrington coordinates in
;the tags CRLN_OBS and CRLT_OBS
;carrCoords=get_stereo_lonlat(date,'Earth',/degrees,system='Carrington')
;print,carrCoords

;Get the open field lines
pfss_get_chfootprint,openfield,/quiet,/usecurrent,spacing=invdens;,/close

;Save the structure and Carrington coordinates of SDO to a sav file:
  if keyword_set(save) then begin
     if not keyword_set(event) then begin
        res=strsplit(date,'/ ',/extract)
        dat=strtrim(res[0]+res[1]+res[2],2)
        fname='pfss_results_'+dat+'_'+strtrim(string(rstart,format='(f4.2)'),2)+'Rs_dens_'+strtrim(string(invdens,format='(f3.1)'),2)+'.sav'
     endif else begin
        dat=event.date        
        fname='pfss_results_'+dat+'_'+event.label+'_'+strtrim(string(rstart,format='(f4.2)'),2)+'Rs_dens_'+strtrim(string(invdens,format='(f3.1)'),2)+'.sav'
     endelse
     save,sph_data,openfield,nstep,filename=path+fname,kind,/comm,/variables,/compress
  endif
end
