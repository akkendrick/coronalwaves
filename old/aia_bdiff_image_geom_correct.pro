pro aia_bdiff_image_geom_correct,data,indices,framerange,eventfile,arlon,proflocs,titprefix=titprefix,outpath=outpath
;This program just corrects the positions determined with the
;aia_bdiff_image_velextract.pro routine for the fact that the wave
;might not be on the limb.

set_plot,'x'

;INPUT
;avgprofile - the average of the radial profiles 
;indices - a corresponding array of data indices
;framerange - the first and last frame for which to measure the
;             transient's position
;proflocs - the position of the profiles, for reference.
;nms - since measuring the points is done manually, this variable has
;      the number of measurements the user has to perform.

;checkbad (optional) - if set, prompt the user to approve each profile
;                      before selecting profile peak
;titprefix (optional) - set to the name of the transient (CME,shock,
;                       etc) (string)
;outpath (optional) - set to the location where the plots of velocity
;                     and position vs. time should be saved. 

;OPTIONAL OUTPUT
;
;if the keyword outpath is set, saves a plot of position vs. time and
;a plot of velocity vs. time for the examined averaged profile.
;



;=============================================================================
;0. Constants, Definitions
if not keyword_set(titprefix) then titprefix='CME Wave' 
wav=strtrim(string(indices[0].wavelnth),2)
date=strmid(indices[0].date_obs,0,4)+strmid(indices[0].date_obs,5,2)+strmid(indices[0].date_obs,8,2)
;measnum=3 ; This variable controls along how many profiles to measure the wave speed.

restore, eventfile


!P.font=-1
loadct,8,/silent 
;tvlct,red,green,blue,/get
!P.position=[0.16,0.1,0.93,0.93]


;The plate scale is index.RSUN_OBS/index.R_SUN, or  ~0.6 "/px.
;Then, the conversion px->km is
;platescale*index.RSUN_REF/index.RSUN_OBS/1000.0, or
;kmpx=(index.RSUN_REF/index.R_SUN)/1000.0 [km/px]
kmpx=indices[0].IMSCL_MP*indices[0].RSUN_REF/(1000.0*indices[0].RSUN_OBS)


;number of time steps
nprofs=n_elements(data[*,0,0])



init=framerange[0] ;the first frame for which to record the position of the feature.
fin=framerange[1]

;peakpos=reform(fltarr(nprofs,nms,fin-init+1,2))

;sigmavel=fltarr(measnum,fin-init+1)
;fitchisq=fltarr(measnum,fin-init+1)


;fitparams=dblarr(measnum,3)
;fitparamssigma=dblarr(measnum,3)


;cmemoments=fltarr(measnum,fin-init+1,3) ;moments of the position of the feature

jdfrac=dblarr(nprofs)

;bad=0

;Convert the time to fractional JD
for i=0,nprofs-1 do begin
tmp=anytim2jd(reform(indices[i].date_obs))
jdfrac[i]=tmp.frac
endfor

time=jdfrac[init:fin]
relmintime=(jdfrac-jdfrac[0])*86400.0
time=(time-time[0])*86400.0
;fitlines=dblarr(measnum,floor(max(time)))
;print,floor(max(time))

proforigin=[proflocs[0,0,0]*kmpx,proflocs[0,1,0]*kmpx]

;create the average for the base difference
;avg=dblarr(1024,1024)
;avg_exptime=average(indices[*].exptime)
;avg=data[0,*,*]*avg_exptime/indices[0].exptime
;for i=1,9 do avg=avg+data[i,*,*]*avg_exptime/indices[i].exptime
;avg=avg/10.0
;=============================================================================




;==================================================================================
;1. For three different radial profiles, select the shock front over
; all time steps, doing it a number of times (N trial measurements)
; for each profile

;for p=0,measnum-1 do begin
;   pnum=floor(p*n_elements(proflocs[*,0,0])/(measnum-1.0))
;   if pnum eq n_elements(proflocs[*,0,0]) then pnum = pnum - 1
;   
;   print,';;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;'
;   print,';;;;;;;;;;;;;;  Measurement along profile #'+strtrim(string(p+1),2)+'  ;;;;;;;;;;;;;;;;;'
;   print,';;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;'
;   print,''
;   for n=0,nms-1 do begin
;      print,'============================================='
;      print,'=================  Trial #'+strtrim(string(n+1),2)+'  ======================'
;      print,'============================================='
;      for i=init,fin do begin
;                                ;rundiffim=data[i,*,*]*avg_exptime/indices[i].exptime-data[i-1,*,*]/indices[i-1].exptime
;         basediffim=data[i,*,*]*avg_exptime/indices[i].exptime-avg
;                                ;tv,diffim+smooth(rundiffim,10)*4
;         tv,basediffim+smooth(basediffim,4)*4
;         plots,proflocs[pnum,0,*],proflocs[pnum,1,*],/device,thick=4
;         ;if n eq 0 and p eq 0 and keyword_set(outpath) then $
;         ;  write_png,outpath+'basediff0612_'+wav+'_'+strtrim(string(i+1000),2)+'.png',tvrd()
;         
;         wait,0.2
;         
;         print,'Click on the feature maximum:'
;         cursor,x,y,/device
;         print, 'You chose x: '+strtrim(string(x),2)+'  y: '+strtrim(string(y),2)
;         plots,x,y,psym=2,symsize=2,thick=3,/device
;;plots,[0,npix*kmpx],[y/2,y/2]
;         
;         peakpos[p,n,i-init,0]=x*kmpx
;         peakpos[p,n,i-init,1]=y*kmpx
;         
;         wait,0.4
;      endfor
;   endfor
;endfor
;==================================================================================



;==================================================================================
;1. Load data and define counters, arrays, etc.
geomcorpeakpos=peakpos
ntimes=n_elements(cmemoments[0,*,0])
nprofs=n_elements(cmemoments[*,0,0])
ntrials=nms

fitlines=dblarr(nprofs,floor(max(time)))
sigmapos=fltarr(nprofs,ntimes)

geomcorfactor=1.0/sin(arlon*!PI/180.0)

;Perform geometric correction for the plane-of-sky projection
for t=0,ntimes-1 do begin
   for p=0,nprofs-1 do for m=0,ntrials-1 do for i=0,1 do $
   geomcorpeakpos[p,m,t,i]=(peakpos[p,m,t,i]-proforigin[i])*geomcorfactor
endfor
;==================================================================================


;==================================================================================
;2. Record the mean and standard deviation of the radial position from
;the measurements, then perform bootstrapping analysis and get good v0
;and a information

for p=0,nprofs-1 do begin

;First, get mean and standard deviation of the positions
   for i=0,ntimes-1 do begin
      res=moment(sqrt((geomcorpeakpos[p,*,i,0])^2+(geomcorpeakpos[p,*,i,1])^2),sdev=sdev)
      sigmapos[p,i]=sdev
      cmemoments[p,i,0]=reform(res[0])

    ;  sigmapos[p,i]=stddev(sqrt(peakpos[p,*,i,0]^2+peakpos[p,*,i,1]^2))
    ;  cmemoments[p,i,0]=average(sqrt((peakpos[p,*,i,0]-proforigin[0])^2+(peakpos[p,*,i,1]-proforigin[1])^2))
   endfor

;calculate the radial velocity
;cmemoments[p,*,1]=deriv(time,cmemoments[p,*,0])
;sigmavel[p,*]=derivsig(time,cmemoments[p,*,0],0.0,reform(sigmapos[p,*]))

;calculate the radial acceleration
;cmemoments[p,*,2]=deriv(time,cmemoments[p,*,1])
print,'Beginning bootstrapping analysis for profile '+strtrim(string(p+1),2)

;Next, feed the positions and standard deviations into the
;bootstrapping code by David Long, and using the following functional
;form: x = p[0] + p[1] * (t) + 0.5D * p[2] * (t)^2
bootstrap_sdo, reform(cmemoments[p,*,0]),time,error=reform(sigmapos[p,*]),fit_line,p1,p2,p3,s1,s2,s3
fitparams[p,*]=reform([p1[0],p2[0],p3[0]])
fitparamssigma[p,*]=[s1,s2,s3]
fitlines[p,*]=fit_line

cmemoments[p,*,1]=p2[0] + time*p3[0]
cmemoments[p,*,2]=fltarr(ntimes)+p3[0]

endfor
;==================================================================================


;stop

 

;=================================================================================
;3. Plot the resulting positions and velocities, show the parameters of the fit
RSUN=6.96e5;radius of the sun, in km.

;3.1 Plot the position as a function of time.
xrange=[min(time)/60.0-0.1,max(time)/60.0+0.1]

reltime=strmid(indices[init].date_obs,11,8)

;date=strmid(indices[init].date_obs,0,10)
if keyword_set(outpath) then set_plot,'z'
wdef,0,1024

min=min(cmemoments[*,*,0]/RSUN+1.0)
max=max(cmemoments[*,*,0]/RSUN+1.0)
yrange=[min/1.1,max*1.1]

for p=0,nprofs-1 do begin


   plot, time/60.0,cmemoments[p,*,0]/RSUN+1.0,$
                        psym=p+5,symsize=1,$
                        title=titprefix+' position versus time, AIA/'+wav+' A',$
                        xtitle='Time relative to '+reltime+' UT, '+date+', [min]', $
                        ytitle='Radial distance, R!DS!N',$
                        thick=4,xthick=2,ythick=2,charsize=1.8,$
                        xrange=xrange,xstyle=1,$
                        yrange=yrange,ystyle=1 ,background=0,color=255

   ;if p gt 0 then oplot,time/60.0,cmemoments[p,*,0],color=255,psym=5+p,symsize=1

;overplot the fit to the user-selected peaks in the profiles
   ;posparams=poly_fit(time/60.0,cmemoments[p,*,0],2,yfit=posfit,yband=posfiterr,measure_errors=sigmapos[p,*],sigma=possigma)
   ;oplot, time/60.0, posfit,color=255



   oploterr, time/60.0,cmemoments[p,*,0]/RSUN+1.0,float(sigmapos[p,*])/RSUN,psym=5+p,color=255.0
   ;oplot, time/60.0, fitlines[p,*],thick=2
   
xin=0.18
yin=0.89
dy=0.025
   xyouts,xin,yin,'r = r!D0!N + v!D0!N * t + 1/2 * a * t!U2!N',charsize=1.8,/normal,color=255
   xyouts,xin,yin-dy,'r!D0!N = '+strtrim(string(fitparams[p,0]/RSUN+1.0,format='(f15.2)'),2)+' R!DS!N +/- '+strtrim(string(fitparamssigma[p,0]/RSUN,format='(f15.6)'),2) + ' R!DS!N',charsize=1.8,/normal,color=255
   xyouts,xin,yin-2*dy,'r!D0!N = '+strtrim(string(fitparams[p,0],format='(f15.2)'),2)+' km +/- '+strtrim(string(fitparamssigma[p,0],format='(f15.2)'),2) + ' km',charsize=1.8,/normal,color=255
   xyouts,xin,yin-3*dy,'v!D0!N = '+strtrim(string(fitparams[p,1],format='(f15.2)'),2)+' km/s +/- '+strtrim(string(fitparamssigma[p,1],format='(f15.2)'),2) + ' km/s',charsize=1.8,/normal,color=255
   xyouts,xin,yin-4*dy,'a = '+strtrim(string(fitparams[p,2],format='(f15.2)'),2)+' km/s!U2!N +/- '+strtrim(string(fitparamssigma[p,2],format='(f15.2)'),2) + ' km/s!U2!N',charsize=1.8,/normal,color=255
   
   
   if keyword_set(outpath) then write_png,outpath+'radPosTime_geom_correct_'+wav+'_profile_'+strtrim(string(p),2)+'.png',tvrd()
   
;overplot the fitted position as a function of time,including errors.
;oplot, time/60.0,gfitmoments[*,0],psym=7,symsize=1
;Use half the FWHM of the Gaussian fit as the error in position
;oploterr,time/60.0, gfitmoments[*,0],siggfitmoments[*,0]
   
;overplot the fit to the estimated Gaussian peaks of the profiles
;res=linfit(time/60.0,gfitmoments[*,0],yfit=posfit)
;oplot, time/60.0, posfit,linestyle=2
if not keyword_set(outpath) then stop

endfor




;3.2. Plot the velocity as a function of time

loadct,0,/silent


min=min(cmemoments[*,*,1])
max=max(cmemoments[*,*,1])
yrange=[min/1.1,max*1.1]

for p=0,nprofs-1 do begin
   
   if p eq 0 then plot, time/60.0,cmemoments[p,*,1],$ ;psym=p+5,symsize=1,$
                        title=titprefix+' derived velocity versus time, AIA/'+wav+' A',$
                        xtitle='Time relative to '+reltime+' UT, '+date+', [min]', $
                        ytitle='Apparent velocity, km/s',$
                        thick=4,xthick=2,ythick=2,charsize=1.8,$
                        xrange=xrange,xstyle=1,$
                        yrange=yrange,ystyle=1,$
                        background=0,color=255
   
   if p gt 0 then oplot,time/60.0,cmemoments[p,*,1],color=255,linestyle=p;,psym=5+p,symsize=1

   plots,[0.77,0.81],[0.87-p*0.02,0.87-p*0.02],linestyle=p,/normal
   xyouts,0.815,0.87-p*0.02,'Profile '+strtrim(string(p+1),2),/normal,charsize=1.8
   

endfor

if keyword_set(outpath) then write_png,outpath+'radVelTime_geom_correct_'+wav+'_profiles.png',tvrd()
;=========================================================

indices=indices[init:fin]
if keyword_set(outpath) then save,fitparams,fitparamssigma,geomcorpeakpos,cmemoments,nms,sigmapos,indices,$
  filename=outpath+'vel_pos_geom_correct_params_'+date+'_'+wav+'.sav'

set_plot,'x'
end
