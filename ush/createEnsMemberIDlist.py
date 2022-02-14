import numpy as np

dta=np.arange(datetime.datetime(2000, 1,1), datetime.datetime(2019,12,31), datetime.timedelta(days=1))
# 7304 days
rid=0
with open('ensMembIDlist.txt', 'w') as f:
	for i in range(dta.shape[0]):
		wd=calendar.weekday(dta[i].astype(object).year,dta[i].astype(object).month,dta[i].astype(object).day)
		if wd==2:
			farr=np.array([np.str(dta[i].astype(object).year),np.str(dta[i].astype(object).month).zfill(2),np.str(dta[i].astype(object).day).zfill(2)])
			for j in range(0,6):
				farr=np.append(farr,np.array(np.str(rid).zfill(2)))
				if rid<4:
					rid=rid+1
				else:
					rid=0

			f.write(" ".join(farr)); f.write('\n'); del farr

