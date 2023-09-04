# -*- coding: utf-8 -*-
"""
Created on Fri Dec 18 00:38:23 2020

@author: hchi
"""

from pyproj import Proj, transform

inProj = Proj(init='epsg:2240', preserve_units = True)
outProj = Proj(init='epsg:4326')
x1,y1 = 2230626.36,1314043.253
x2,y2 = transform(inProj,outProj,x1,y1)
print(y2,x2)

import json
import urllib.request

# download raw json object
url = "http://127.0.0.1:5000/route/v1/driving/-84.2673429,33.78335509;-84.4415687,33.79003609?steps=false"
data = urllib.request.urlopen(url).read().decode()

# parse json object
obj = json.loads(data)

# output some object attributes
print(obj['routes'][0]['distance'])
print(obj['routes'][0]['duration'])