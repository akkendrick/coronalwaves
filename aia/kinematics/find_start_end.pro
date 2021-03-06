pro find_start_end, data, time, rad, startInd=startInd, endInd=endInd

;PURPOSE
;Procedure to automatically find initial estimates of the start end times of the EUV front
;Takes data, sums up pixel intensities at each time step, determines
;start and end times from a Gaussian fit and how the sum of intensities change
;
;INPUTS
;     DATA - annulus data from aia_annulus_analyze_radial.pro
;     TIME - array of times to corresponding annulus data
;     RAD - array of radii used in the data
;OUTPUTS
;     STARTIND - index of front start position
;     ENDIND - index of front end position

  ; To print out additional information set debug to 1
  debug = 0

  nt = n_elements(time)
  dat=data

  ind=where(dat lt 0.0)
  if ind[0] gt -1 then dat[ind] = 0.0

  ; Go through and sum up the intensities for each time step
  totalPixVals=dblarr(nt)
  for tt=0,nt-1 do begin
     tmp=total(dat[tt,*])
     totalPixVals[tt]=tmp
  endfor

  ; Smooth the sum of the pixel intensities for min detection
  totalSmoothVals = smooth(totalPixVals, 6, /edge_truncate)
  tmp = lindgen(n_elements(totalSmoothVals))

  ; Compute minima and maxima to center Gaussian fit on first wave
  maxima = get_local_maxima(totalSmoothVals, tmp)
  minind = lclxtrem(totalSmoothVals-smooth(totalSmoothVals, 20, /edge_truncate), 10)

  firstMaxInd = where(maxima.ind eq min(maxima.ind))
  goodMinInd = min(where(minind gt maxima[firstMaxInd].ind))

  if goodMinInd eq -1 then begin
     minind[goodMinInd] = n_elements(data)-1
  endif

  x = lindgen(n_elements(totalPixVals))

  ; If more than one max is found, use the first otherwise there is
  ; only one wave present in the data and filtering is unnecessary
  if n_elements(maxima) gt 1 then begin
     ; Correct for smoothing
     corr = 0

     ; Make sure to not prematurely cut off the Gaussian fit if
     ; we have found the biggest one
     if maxima[firstMaxInd].val eq max(maxima.val) then begin
        gaussData = totalPixVals
     endif else begin
        if minind[goodMinInd] + corr gt n_elements(totalPixVals)-1 then corr=0
        gaussData = totalPixVals[0:minind[goodMinInd]+corr]
        x = x[0:minind[goodMinInd]+corr]
     endelse
  endif else begin
     gaussData = totalPixVals
  endelse 
     
x=lindgen(n_elements(totalPixVals))
gaussData=totalPixVals


  cgplot, totalPixVals, /window

;  cgplot, time.jd, totalSmoothVals, title="Summed Pixel Intensities vs Time", xtickformat='LABEL_DATE',$
;          xtickunit='Time', xtitle='Time (UT)', ytitle='Summed Pixel Intensities', thick=3, /window

  ; Compute a Gaussian fit to determine start and end times
  gfit2 = gaussfit(x, gaussData, coeff, estimates=estimates, nterms=4)
  cgPlot, gfit2, /overPlot, color='green', /window

  ; If the peak or stdev is outrageous, refit with all of the data
  if coeff[2] gt n_elements(totalPixVals)/2 || coeff[0] lt 0 then begin
     x = lindgen(n_elements(totalPixVals))
     gfit2 = gaussfit(x, totalPixVals, coeff, estimates=estimates, nterms=4)
  endif

  minusTwoSigma = coeff[1] - 2*coeff[2]
  plusTwoSigma = coeff[1] + 2*coeff[2]
  
  ;; timeTwoSigma = time[round(plusTwoSigma)].jd
  ;; mtimeTwoSigma = time[round(minusTwoSigma)].jd

  ;; cgPlot, [timeTwoSigma, timeTwoSigma], [0, 4000], /Overplot, /window
  ;; cgPlot, [mtimeTwoSigma, mtimeTwoSigma], [0, 4000], /Overplot, /window  
  
  cgPlot, [plusTwoSigma, plusTwoSigma], [0, 800], /Overplot, /window
  cgPlot, [minusTwoSigma, minusTwoSigma], [0, 800], /Overplot, /window  
  


  ; Refit the Gaussian with all of the
  ; data if the initial start guess is negative
  if minusTwoSigma lt 0 then begin
     x = lindgen(n_elements(totalPixVals))
     gfit2 = gaussfit(x, totalPixVals, coeff, estimates=estimates, nterms=4)

     minusTwoSigma = coeff[1] - 2*coeff[2]
     plusTwoSigma = coeff[1] + 2*coeff[2]

     if minusTwoSigma lt 0 then begin
        startInd = -1
        endInd = -1
        print, "No valid start point found, exiting..."
        return
     endif
       
     cgPlot, [plusTwoSigma, plusTwoSigma], [0, 800], /Overplot, /window
     cgPlot, [minusTwoSigma, minusTwoSigma], [0, 800], /Overplot, /window  
  endif
     
;--------------------------------------------------------------------
; OLD VERSION - Exceed a running mean for a specified number of time steps

  ;; prevVal = totalPixVals[0]
  ;; maxDuration = 0
;; ; Primary scan - look for data which exceeds a running 
;; ; mean of totalPixVals
;;   currentMean = totalPixVals[0]
;;   backgroundEnd = -1
;;   for tt=0, nt-1 do begin
;;      currentMean = mean(totalPixVals[0:tt])
;;      if debug eq 1 then begin
;;         print, "Current running mean is: ", currentMean
;;         print, "Current total pixel value is: ", totalPixVals[tt]
;;      endif 
;;      if totalPixVals[tt] gt currentMean then begin
;;         maxDuration++
;;         if debug eq 1 then print, "Number of times running average exceeded: ", maxDuration
;;      endif else begin
;;         maxDuration = 0 
;;      endelse
;; ; If we have exceeded the mean for 6 timesteps save
;; ; this as the end of the quiet background of totalPixVals
;;      if maxDuration gt 6 then begin
;;         backgroundEnd = tt
;;         print, "Location of background end: ", backgroundEnd
;;         break
;;      endif
;;   endfor

;--------------------------------------------------------------------

; NEW VERSION
; Use GaussFit to provide initial starting and ending
; time guess

  startGuess = round(minusTwoSigma)
  endGuess = round(plusTwoSigma)

  backgroundLevel = mean(totalPixVals[0:startGuess])
  backgroundThresh = backgroundLevel + 0.50*backgroundLevel

  ; Make sure the first maxima is sufficiently above background
  if maxima[firstMaxInd].val lt backgroundThresh then begin
     if debug eq 1 then print, "Below background threshold, recomputing..."
     x = lindgen(n_elements(totalPixVals))
     gfit2 = gaussfit(x, totalPixVals, coeff, estimates=estimates, nterms=4)
     cgPlot, gfit2, /OverPlot, color='green', /window

     minusTwoSigma = coeff[1] - 2*coeff[2]
     plusTwoSigma = coeff[1] + 2*coeff[2]
  
     cgPlot, [plusTwoSigma, plusTwoSigma], [0, 800], /Overplot, /window
     cgPlot, [minusTwoSigma, minusTwoSigma], [0, 800], /Overplot, /window  

     startGuess = round(minusTwoSigma)
     endGuess = round(plusTwoSigma)
  endif

  if debug eq 1 then begin
     print, "Gaussian based start index guess"
     print, startGuess
     print, "Gaussian based end index guess"
     print, endGuess
  endif
  
  backgroundEnd = startGuess
  
  slope = dblarr(nt)
  julianTime = time.jd
  
; Make sure valid data was actually found
  if backgroundEnd eq -1 then begin
     startInd = -1
     endInd = -1
     return
  end

; Select an end window location for slope computation
  endWindow = backgroundEnd+20
  startWindow = backgroundEnd
  if backgroundEnd+20 gt n_elements(totalPixVals)-1 then endWindow = n_elements(totalPixVals)-1
  if startWindow le 0 then startWindow = 1
  
; For a window around the end of the background compute the slope
  for tt=startWindow, endWindow do begin
     slope[tt] = (totalPixVals[tt] - totalPixVals[tt-1])
     if debug eq 1 then begin
        print, "Current step: ", tt
        print, "Current slope: ", slope[tt]
     endif
  endfor
  
; Ideally the front should be marked by a rapid increase in the 
; slope, finding the place where we have a large slope within
; the background window should mark the start of the front.
; Save this as the starting index
  startInd = min(where(slope gt 225))

  if debug eq 1 then print, "Slope detected start: ", startInd

  if startInd eq -1 then begin
     print, "Could not find valid slope based starting point"
     print, "Using Gaussian based start index guess"
     startInd = startGuess
  endif

  ; If the Gaussian fit is incomplete, force a gaussian fit over all data
  if startInd gt n_elements(gfit2)-1 then begin
     x = lindgen(n_elements(totalPixVals))
     gfit2 = gaussfit(x, totalPixVals, coeff, estimates=estimates, nterms=4)
  endif

; To find the end position, define a threshold
; based on the mean pixel value of the background
  backgroundLevel = mean(totalPixVals[0:backgroundEnd])
  
; Look for when the Gaussian fit crosses 10% of this threshold
  threshold = 0.10
  endLevel = backgroundLevel + threshold*backgroundLevel

  if debug eq 1 then print, "Background threshold at: ", endLevel

  ; First try and find when the data crosses the background
  endInd = -1
  for tt = startInd, nt -1 do begin
     if totalPixVals[tt] lt endLevel then begin
        endTime = time[tt]
        endInd = tt
        if debug eq 1 then print, "End Index: ", endInd
        break
     endif
  endfor

  ; If unsuccesful, find where the Gaussian crosses the background
  if endInd eq -1 then begin
     for tt=startInd, nt-1 do begin
                                ;print, totalPixVals[tt]
                                ; Save the first instance of falling below the
                                ; threshold as the end index
        if tt eq n_elements(totalPixVals) then break
        if tt eq n_elements(gfit2) then break
        
        if gfit2[tt] lt endLevel then begin
           endTime = time[tt]
           endInd = tt
           if debug eq 1 then print, "End Index: ", endInd
           break
        endif
     endfor
  endif

  ; If nothing works use the Gaussian based two sigma guess
  if endInd eq -1 then begin
     print, "Could not find valid ending point, using Gaussian based guess"
     endInd = endGuess
     if endInd gt n_elements(totalPixVals)-1 then endInd = n_elements(totalPixVals)-2
     return
  endif

  print, "Start Index: ", startInd
  print, "Start Time: ", time[startInd]
  print, "End Index: ", endInd
  print, "End Time: ", time[endInd]

end
