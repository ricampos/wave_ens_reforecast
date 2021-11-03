Instructures for setting up Wave Ensemble Reforecast 
* Note this is a work in progress and the repo will be moved to a NOAA-EMC location

#Clone repo
git clone https://github.com/JessicaMeixner-NOAA/wave_ens_reforecast

# Checkout Model 

From sorc/ directory:  
sh checkout.sh 

# Build Model & Other Execs 

From sorc/directory: 
sh build_ww3prepost.sh 

Requests of features from Ricardo: 

- One cycle per day (starting at 03Z), with restart file for +24h
- 5(or 11) ensemble members
- New list of point output (parm/wave/bstations_GEFSv12WW3grid.txt)
- New list of output fields
-- Grib: HS FP DP
-- Netcdf: WND HS FP T01 T02 DIR DP SPR PHS PTP PDIR
- DT point output is 1 hour 
- DT for gridded output is 3 hours  
- We can keep grib2 format for output fields, but netcdf format for the point output files will be much easier to handle and to compare with observations;
- Suggestion: 7 simulations (1week) per job, to optimize Orion queue time.
- 4 streams: blocks of 5 years, starting at 2000, 2005, 2010, and 2015.


Jesssica's notes: 

GEFS winds and ice: /work/noaa/marine/ricardo.campos/data/GEFSv12
Point output list: /work/noaa/marine/ricardo.campos/data/buoys/bstations_GEFSv12WW3grid.txt 

* Create mod_def once and store it 
* Prep of wind and ice will be in workflow 
* 1 forecast will use 10 nodes, 40 tasks/node takes ~32 min for 16 days or ~1 hour 7 min for 35 days
* Restart dt will be 24 hours 
* Requested to not use check-point output and instead use one file for point/gridded output 
* Point output should be netcdf spec and table (Example templates in parm/wave dir)  
* Gridded, wants both netcdf and grib with different lists of files 
* Can clean-up binary run data as we go 
* Python post processing, Ricardo will provide script, module and resources 



Issue: Need to get hpc-stack netcdf issue resolved  
