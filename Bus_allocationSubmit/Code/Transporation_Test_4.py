# -*- coding: utf-8 -*-
"""
Created on Sun Dec  6 01:29:34 2020

@author: hchi

"""
import pandas as pd
import numpy as np
from solver import *
from distance_Calculation import *
from facility_summary import *
from pyscipopt import Model,quicksum

deadhead_data = pd.read_csv(f'inputs/scenario_4/ALL_deadhead_dist_4.csv')
facility_data = pd.read_csv(f'inputs/scenario_4/facility_location.csv')

deadhead_data['veh']=1
I=deadhead_data['block_id'].values.tolist()
J=facility_data['facility_id'].values.tolist()
J1=facility_data.loc[facility_data['facility_type']==1,'facility_id'].values.tolist()  ##existing facility
J2=facility_data.loc[facility_data['facility_type']==2,'facility_id'].values.tolist()  ## new facility
d = deadhead_data[['block_id','veh']].set_index('block_id').to_dict()['veh']
M =facility_data[['facility_id','capacity']].set_index('facility_id').to_dict()['capacity']
cost =facility_data[['facility_id','facility_cost']].set_index('facility_id').to_dict()['facility_cost']
c={}

deadhead_matrix=cal_distance(facility_data,deadhead_data)
deadhead_matrix=deadhead_matrix.set_index('block_id')
Name=list(deadhead_matrix.columns.values) 
L=deadhead_matrix.to_dict()
for fkey in Name:
    for rkey in L[fkey]:
        c[(rkey,fkey)]=L[fkey][rkey]
        
model = Model("transportation")
x = {}
y={}
for i in I:
    for j in J:
        x[i,j] = model.addVar(vtype="I", name="x(%s,%s)" % (i,j))
for j in J:
        y[j] = model.addVar(vtype="B", name="y(%s)" % (j))
for i in I:
    model.addCons(quicksum(x[i,j] for j in J if (i,j) in x) == d[i], name="Demand(%s)" % i)
for j in J:
    model.addCons(quicksum(x[i,j] for i in I if (i,j) in x) <= M[j]*y[j], name="Capacity(%s)" % j)
model.addCons(quicksum(y[j] for j in J1) == 3, name="existing facility number")

model.setObjective(quicksum(c[i,j]*x[i,j]  for (i,j) in x)+quicksum(cost[j]*y[j]  for (j) in y), "minimize")
model.optimize()
print("Optimal value:", model.getObjVal())
EPS = 1.e-6

for (i,j) in x:
    if model.getVal(x[i,j]) > EPS:
        print((model.getVal(x[i,j]),i,j))

for j in y:
    if model.getVal(y[j]) > EPS:
        print((model.getVal(y[j]),j))
# Initialize a data frame to store results:
	# (1) changes in deadhead time
dh_current = np.array(deadhead_data.copy()) 
	# (2) accumulated deadhead time
#accu_dh = np.zeros(deadhead_data.shape)
accu_dh = pd.DataFrame(data = 0, index = deadhead_matrix.index, columns = deadhead_matrix.columns)
    # (3) veh allocation results
#veh_asgn = np.zeros(deadhead_data.shape)
veh_asgn = pd.DataFrame(data = 0, index = deadhead_matrix.index, columns = deadhead_matrix.columns)
    # (4) changes of vehicles left in each facility
veh_left = facility_data.copy()
veh_left = veh_left[["facility_id", "capacity"]]
veh_left = veh_left.set_index('facility_id')
    # (5) changes of vehicles required for each routes
veh_req = deadhead_data.copy()
veh_req = veh_req[["block_id", "veh"]]
veh_req=veh_req.set_index('block_id')
        
for (i,j) in x:
    if model.getVal(x[i,j]) > EPS:
        dh_value=deadhead_matrix.loc[i,[j]]
        num_veh_asgn=model.getVal(x[i,j])
        accu_dh.loc[i, [j]] += dh_value * num_veh_asgn
        veh_asgn.loc[i, [j]] += num_veh_asgn
        veh_left.loc[j, ["capacity"]] -= num_veh_asgn
        veh_req.loc[i, ["veh"]] -= num_veh_asgn
        # print if the process is success or if facilities run out of vehicles
        if sum(veh_req["veh"]) == 0:
            print("Success")
        elif sum(veh_left["capacity"]) == 0:
            print("Fail: facilities run out of vehicles")
	# convert accu_dh and veh_asgn from numpy array to pandas DataFrame
deadassign=deadhead_matrix*veh_asgn

deadnew=deadassign.sum().sum()

deadassign['deaddist_alloc']= deadassign.sum(axis=1)
#deadassign['alloc_div']=""

for index, row in deadassign.iterrows():
    for name in Name:
        if(row[name]>0):
            deadassign.at[index,'alloc_div']=name
deadalloc = deadassign[['deaddist_alloc','alloc_div']]
deadhead_data=deadhead_data.set_index('block_id')  

## joint deadhead_data to deadhead
deadhead_data= deadhead_data.merge(deadalloc, on=['block_id'])  

## summarize the total 
bbay_util, facility_util,dead_mileage,tot_mileage=facilitysummary_existing(facility_data,deadhead_data)
bbay_util2, facility_util2,dead_mileage2,tot_mileage2=facilitysummary_realloc(facility_data,deadhead_data)

veh_req = veh_req.reset_index()
veh_left = veh_left.reset_index()

from functools import reduce
bbay_util_df=pd.DataFrame(bbay_util.items(), columns=['facility_id', 'bbay_util_Ex']).set_index('facility_id')
facility_util_df=pd.DataFrame(facility_util.items(), columns=['facility_id', 'ft_util_Ex']).set_index('facility_id')
dead_mileage_df=pd.DataFrame(dead_mileage.items(), columns=['facility_id', 'deadmile_Ex']).set_index('facility_id')
tot_mileage_df=pd.DataFrame(tot_mileage.items(), columns=['facility_id', 'totalmile_Ex']).set_index('facility_id')
data_frames = [bbay_util_df, facility_util_df,dead_mileage_df,tot_mileage_df]
df_merged = reduce(lambda  left,right: pd.merge(left,right,on=['facility_id'], how='outer'), data_frames)

