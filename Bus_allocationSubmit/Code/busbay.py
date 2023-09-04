# -*- coding: utf-8 -*-
"""
Created on Fri Dec 18 06:11:14 2020

@author: hchi
"""
import pandas as pd
import numpy as np
facility_data = pd.read_csv(f'inputs/scenario_4/facility_location.csv')
deadhead_data = pd.read_csv(f'inputs/scenario_4/ALL_deadhead_dist_4.csv')
deadhead_data= deadhead_data.merge(deadalloc, on=['block_id'])  
### the following is for the fixed facility assignment
deadhead_data['totalmile'] = deadhead_data['Deaddistfix']+deadhead_data['deaddist_mid']+deadhead_data['distance']
deadhead_data['deadmile'] = deadhead_data['Deaddistfix']+deadhead_data['deaddist_mid']
tot_mileage=deadhead_data.groupby("start_div")['totalmile'].sum().to_dict()
dead_mileage=deadhead_data.groupby("start_div")['deadmile'].sum().to_dict()
ft_rename=facility_data[['facility_alias','facility_id']].set_index('facility_alias').to_dict()['facility_id']
for key in ft_rename:
    if(key in tot_mileage):
        tot_mileage[ft_rename[key]] =  tot_mileage.pop(key)
        dead_mileage[ft_rename[key]] = dead_mileage.pop(key)
deadhead_data['totalmile2'] = deadhead_data['deaddist_alloc']+deadhead_data['deaddist_mid']+deadhead_data['distance']
deadhead_data['deadmile2'] = deadhead_data['deaddist_alloc']+deadhead_data['deaddist_mid']
tot_mileage2=deadhead_data.groupby("alloc_div")['totalmile2'].sum().to_dict()
dead_mileage2=deadhead_data.groupby("alloc_div")['deadmile2'].sum().to_dict()
busbay=facility_data[['facility_id','busbay']].set_index('facility_id').to_dict()['busbay']
capacity=facility_data[['facility_id','capacity']].set_index('facility_id').to_dict()['capacity']  # parking space
facility_veh=deadhead_data.groupby("start_div")['totalmile'].count().to_dict()
for key in ft_rename:
    if(key in facility_veh):
        facility_veh[ft_rename[key]] = facility_veh.pop(key)
facility_veh2=deadhead_data.groupby("alloc_div")['totalmile2'].count().to_dict()
annufac_mile=330.6
annufac_bbay=250.0
bbay_turnover=1
fac_insp=6000.0
fac_eng=36000.0
fac_mid=250000.0
fac_majorfail=264.0
fac_majorfail_w=0.5
sch_demand={}
unsch_demand={}
maintenance_demand={}
bbuy_supply={}
bbuy_util={}
bbuy_util2={}
facility_util={}
facility_util2={}
for facility in tot_mileage:
    sch_demand[facility]=tot_mileage[facility]*annufac_mile/fac_insp+tot_mileage[facility]*annufac_mile/fac_eng
    unsch_demand[facility]=tot_mileage[facility]*annufac_mile*fac_majorfail/10**6*fac_majorfail_w
    maintenance_demand[facility]=sch_demand[facility]+unsch_demand[facility]
    bbuy_supply[facility]=busbay[facility]*bbay_turnover*annufac_bbay
    bbuy_util[facility]=maintenance_demand[facility]/bbuy_supply[facility]
    facility_util[facility]=facility_veh[facility]/capacity[facility]
for facility in tot_mileage2:
    sch_demand[facility]=tot_mileage2[facility]*annufac_mile/fac_insp+tot_mileage2[facility]*annufac_mile/fac_eng
    unsch_demand[facility]=tot_mileage2[facility]*annufac_mile*fac_majorfail/10**6*fac_majorfail_w
    maintenance_demand[facility]=sch_demand[facility]+unsch_demand[facility]
    bbuy_supply[facility]=busbay[facility]*bbay_turnover*annufac_bbay
    bbuy_util2[facility]=maintenance_demand[facility]/bbuy_supply[facility]
    facility_util2[facility]=facility_veh2[facility]/capacity[facility]
    

