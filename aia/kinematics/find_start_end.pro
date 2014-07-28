pro find_start_end, data, time, rad, startInd=startInd, endInd=endInd, mymaxima=mymaxima, wave_frontedge=wave_frontedge,$
                    maxRadIndex=maxRadIndex, startCorr=startCorr, endCorr=endCorr

;PURPOSE
;Procedure to automatically find initial estimates of the start end times of the EUV front
;Takes data, sums up pixel intensities at each time step, determines
;start and end times from how the sum of intensities change
;
;INPUTS
;     DATA - annulus data from aia_annulus_analyze_radial.pro
;     TIME - array of times to corresponding annulus data
;
;OUTPUTS
;     STARTIND - index of front start position
;     ENDIND - index of front end position

  ; To print out additional information set debug to 1
  debug = 1

  nt = n_elements(time)
  dat=data
  
  ; Set the initial start correction to zero
  startCorr = 0

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
     if minind[goodMinInd] + corr gt n_elements(totalPixVals)-1 then corr=0
     gaussData = totalPixVals[0:minind[goodMinInd]+corr]
     x = x[0:minind[goodMinInd]+corr]
  endif else begin
     gaussData = totalPixVals

  endelse 
     
  ;cgplot, totalPixVals, /window
  cgplot, totalSmoothVals, /window

  gfit2 = gaussfit(x, gaussData, coeff, estimates=estimates, nterms=4)
  cgPlot, gfit2, /overPlot, color='green', /window
  
  ; If the peak or stdev is outrageous, refit with all of the data
  if coeff[2] gt n_elements(totalPixVals)/2 || coeff[0] lt 0 then begin
     x = lindgen(n_elements(totalPixVals))
     gfit2 = gaussfit(x, totalPixVals, coeff, estimates=estimates, nterms=4)
  endif


  help, coeff, /str
  print, coeff

  minusTwoSigma = coeff[1] - 2*coeff[2]
  plusTwoSigma = coeff[1] + 2*coeff[2]
  
  cgPlot, [plusTwoSigma, plusTwoSigma], [0, 800], /Overplot, /window
  cgPlot, [minusTwoSigma, minusTwoSigma], [0, 800], /Overplot, /window  

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

; Improved Primary scan, using GaussFit to provide initial starting
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

; To find the end position, define a threshold
; based on the mean pixel value of the background
  backgroundLevel = mean(totalPixVals[0:backgroundEnd])
  
; Look for when the Gaussian fit crosses 10% of this threshold
  threshold = 0.10
  endLevel = backgroundLevel + threshold*backgroundLevel

  endInd = -1  
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
