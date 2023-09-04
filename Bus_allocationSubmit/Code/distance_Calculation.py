# -*- coding: utf-8 -*-
"""
Created on Fri Dec 18 00:38:23 2020
calculate the distance between new facility and each block by using OSM

@author: hchi
"""
import pandas as pd
import json
import urllib.request
def cal_distance(facility_data,deadhead_data):
    #facility_data = pd.read_csv(f'inputs/scenario_4/facility_location.csv')
    aliaslist=facility_data['facility_alias'].values.tolist()
    ftname =facility_data[['facility_id','facility_alias']].set_index('facility_alias').to_dict()['facility_id']
    #deadhead_data = pd.read_csv(f'inputs/scenario_4/ALL_deadhead_dist_4.csv')
    facility_data = facility_data[(facility_data['facility_type'] == 2)]

    # download raw json object
    for index, row in facility_data.iterrows():
        flong=row['ft_long']
        flat=row['ft_lat']
        falias=row['facility_alias']
        deadhead_data['distance_'+falias] = 0.0
        for index,row in deadhead_data.iterrows():
            slong=row['SLong']
            slat=row['SLat']
            elong=row['ELong']
            elat=row['ELat']
            url = "http://127.0.0.1:5000/route/v1/driving/"+str(flong)+","+str(flat)+";"+str(slong)+","+str(slat)+"?steps=false"
            url1 = "http://127.0.0.1:5000/route/v1/driving/"+str(flong)+","+str(flat)+";"+str(elong)+","+str(elat)+"?steps=false"
            data = urllib.request.urlopen(url).read().decode()
            data1 = urllib.request.urlopen(url1).read().decode()
            obj = json.loads(data)
            obj1 = json.loads(data1)
            distance=(obj['routes'][0]['distance']+obj1['routes'][0]['distance'])/1000/1.60934
            deadhead_data.at[index,'distance_'+falias]=distance
    ##output the deadheadmatrix
    deadhead_datanew= pd.DataFrame() #creating an empty dataframe
    for index,i in deadhead_data.iterrows():
        deadhead_datanew.loc[index,'block_id']=deadhead_data.loc[index,"block_id"]
        for item in aliaslist:
            deadhead_datanew.loc[index,ftname[item]]=deadhead_data.loc[index,"distance_"+item]
    return deadhead_datanew
        


