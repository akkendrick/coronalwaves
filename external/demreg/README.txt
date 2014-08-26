This code performs a regularized inversion (Tikhonov 1963) on multi-filter
and/or spectroscopic line intensities with the corresponding temperature
response/contribution functions to calculate the Differential Emission Measure
(DEM), as detailed in Hannah & Kontar A&A 2011. The is an modification of the
regularized inversion code already included in the xray ssw package (Kontar et
al 2004 Sol Phys) under $SSW/packages/xray/idl/inversion/.

IGH 18-Nov-2011

##############################################

The main driver programs is:
data2dem_reg.pro

##############################################

The regularization is performed in various steps using dem_inv_*
dem_inv_make_constraint.pro	
	 ** Calculates the chosen constraint matix
dem_inv_gsvdcsq.pro			
	  **Performs GSVD
dem_inv_reg_parameter.pro		
	  ** Calculate the regularization parameter
dem_inv_reg_parameter_pos.pro		
	  ** Additional version that calculates reg param and solution for positive case
dem_inv_reg_solution.pro		
	  ** Calculates the regularized solution
dem_inv_reg_resolution.pro		
	  ** Calculates the DEM horizontal error (temperature resolution)
dem_inv_confidence_interval.pro	
	** Calculates the DEM vertical error	

##############################################

Example scripts are given for SDO/AIA and Hinode/EIS for a variety of DEMs.
These are batch scripts so to execute just via
IDL>@aia_example

aia_example.pro		
	** SDO/AIA with a Guassian DEM Model
aia_example_ar.pro		
	** SDO/AIA with the CHINATI Active Region DEM Model
line_example.pro		
	 ** Hinode/EIS with the CHINATI Quiet Sun DEM Model

For the CHIANTI model DEM examples both the SDO/AIA and chianti ssw packages need to
be installed, i.e. setenv SSW_INSTR "aia chianti"

##############################################

The code is distributed under a Creative Commons through the
Attribution-Noncommercial-Share Alike 3.0 license (can copy, distribute and
adapt the work but full attribution must be given and cannot be used for
commercial purposes)
