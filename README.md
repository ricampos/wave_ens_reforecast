
# Checkout Model 

From sorc/ directory:  
sh checkout.sh 


# Build Model & Other Execs 

From sorc/directory: 
sh build_ww3prepost.sh 


Requests of features from Ricardo: 

- One cycle per day (starting at 03Z), with restart file for +24h;
- 5(or 11) ensemble members;
- New list of point output;
- New list of output fields;
- Suggestion: point output step of 3600s instead of 10800s.
- We can keep grib2 format for output fields, but netcdf format for the point output files will be much easier to handle and to compare with observations;
- Suggestion: 7 simulations (1week) per job, to optimize Orion queue time.
- 4 streams: blocks of 5 years, starting at 2000, 2005, 2010, and 2015.


GEFS winds and ice: /work/noaa/marine/ricardo.campos/data/GEFSv12
Point output list: /work/noaa/marine/ricardo.campos/data/buoys/bstations_GEFSv12WW3grid.txt
