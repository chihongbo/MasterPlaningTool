import pandas as pd
import numpy as np
from distance_Calculation import *
from facility_summary import *
from pyscipopt import Model,quicksum

def del_route(route_data, route_id, deadhead_data):
	""" Delete route from route_data and deadhead_data based on route_id

	Args:
		route_data: route DataFrame; 4 columns: route_id, route_type, latitude, longitude
		route_id: a string indicating route_id
		deadhead_data: deadhead DataFrame; route_id as row index and facility_id as column index
	
	Returns:
		A tuple with processed route_data and deadhead_data
	"""
	route_list = route_data["route_id"].tolist()
	route_data = route_data.drop(route_list.index(route_id), axis = 0).reset_index(drop = True)
	deadhead_data = deadhead_data.drop(route_id)
    #deadhead_data = deadhead_data.drop(route_list.index(route_id), axis = 0).reset_index(drop = True)
	return route_data, deadhead_data

def del_facility(facility_data, facility_id, deadhead_data):
	""" Delete facility from facility_data and deadhead_data based on facility_id

	Args:
		facility_data: facility DataFrame; 4 columns: facility_id, capacity, latitude, longitude
		facility_id: a string indicating facility_id
		deadhead_data: deadhead DataFrame; route_id as row index and facility_id as column index

	Returns: 
		A tuple with processed facility_data and deadhead_data
	"""
	facility_list = facility_data["facility_id"].tolist()
	facility_data = facility_data.drop(facility_list.index(facility_id), axis = 0).reset_index(drop = True)
	deadhead_data = deadhead_data.drop(facility_id, axis='columns')
	return facility_data, deadhead_data

def solve(deadhead_data, facility_data, route_data):
	""" Solve bus allocation probelm.

	Args:
		deadhead_data: deadhead DataFrame; route_id as row index and facility_id as column index
		facility_data: facility DataFrame; 4 columns: facility_id, capacity, latitude, longitude
		route_data: route DataFrame; 4 columns: route_id, route_type, latitude, longitude
	
	Returns:
		A tuple with processing results:
			accu_dh: accumulated deadhead matrix (in numpy array format)
			veh_asgn: vehicle assignment result (in numpy array format)
			veh_left: a DataFrame with num of vehicles left in facilities
			veh_req: a DataFrame with number of vehicles required in facilities
	"""
	# Initialize a data frame to store results:
	# (1) changes in deadhead time
	dh_current = np.array(deadhead_data.copy()) 
	# (2) accumulated deadhead time
	accu_dh = np.zeros(deadhead_data.shape)
	# (3) veh allocation results
	veh_asgn = np.zeros(deadhead_data.shape)
	# (4) changes of vehicles left in each facility
	veh_left = facility_data.copy()
	veh_left = veh_left[["facility_id", "capacity"]]
	# (5) changes of vehicles required for each routes
	veh_req = route_data.copy()
	veh_req = veh_req[["route_id", "veh"]]

	# try assigning vehicles all at once using the min deadhead time for each route
	row_ix = np.arange(dh_current.shape[0])
	col_ix = np.nanargmin(dh_current, axis=1)
	veh_asgn[row_ix, col_ix] = veh_req["veh"]
	accu_dh[row_ix, col_ix] = veh_req["veh"] * dh_current[row_ix, col_ix]
	veh_left["capacity"] -= veh_asgn.sum(axis = 0)
	veh_req["veh"] -= veh_asgn.sum(axis = 1)

	if not (veh_left["capacity"] > 0).all(): # check if all remaining capacity are > 0
		# Initialize a data frame to store results:
		# (1) changes in deadhead time
		dh_current = np.array(deadhead_data.copy()) 
		# (2) accumulated deadhead time
		accu_dh = np.zeros(deadhead_data.shape)
		# (3) veh allocation results
		veh_asgn = np.zeros(deadhead_data.shape)
		# (4) changes of vehicles left in each facility
		veh_left = facility_data.copy()
		veh_left = veh_left[["facility_id", "capacity"]]
		# (5) changes of vehicles required for each routes
		veh_req = route_data.copy()
		veh_req = veh_req[["route_id", "veh"]]
        

		# Begin iteration
		iter_num = 0
		while(sum(veh_req["veh"]) > 0 and sum(veh_left["capacity"]) > 0):
			iter_num += 1
			print("iteration:", iter_num)

			# check if there is any remaining vehes in each facility > 0. If no veh left, set to "nan" in the deadhead df.
			dh_current[:,np.where(veh_left["capacity"]==0)] = np.nan
			
			# check if there is any unfulfilled routes (veh required > 0). If no more veh needed, set to "nan" in the deadhead df.
			dh_current[np.where(veh_req["veh"]==0), :] = np.nan

			# find minimum deadhead time & its corresponding facility & route
			min_dh =  np.nanmin(dh_current)
			update_route = np.where(dh_current == min_dh)[0][0] # Find row index. The result would be which route to update in this iteration
			from_facility = np.where(dh_current == min_dh)[1][0] # Find column index. The result would be which facility to update in this iteration

			# assign as many veh as possible from a min deadhead facility to fill the route requirement
			num_veh_asgn = min(int(veh_left.loc[from_facility,["capacity"]]), int(veh_req.loc[update_route, ["veh"]]))

			# update accumulated deadhead time dataframe, veh assignment result, remaining veh in each facility, and remaining required vehes for each route
			accu_dh[update_route, from_facility] += min_dh * num_veh_asgn
			veh_asgn[update_route, from_facility] += num_veh_asgn
			veh_left.loc[from_facility, ["capacity"]] -= num_veh_asgn
			veh_req.loc[update_route, ["veh"]] -= num_veh_asgn
			# print("vehicle remained:\n", veh_left)
			# print("veh_req:\n", veh_req)
			# print("accumulated deadhead:\n", accu_dh)

			# print if the process is success or if facilities run out of vehicles
			if sum(veh_req["veh"]) == 0:
				print("Success")
			elif sum(veh_left["capacity"]) == 0:
				print("Fail: facilities run out of vehicles")

	# convert accu_dh and veh_asgn from numpy array to pandas DataFrame
	accu_dh = pd.DataFrame(data = accu_dh, index = deadhead_data.index, columns = deadhead_data.columns)
	veh_asgn = pd.DataFrame(data = veh_asgn, index = deadhead_data.index, columns = deadhead_data.columns)

	print("final accumulated deadhead:", accu_dh.sum())
	return accu_dh, veh_asgn, veh_left, veh_req


def solve_or(deadhead_data, facility_data, route_data):
    I=route_data['route_id'].values.tolist()
    J=facility_data['facility_id'].values.tolist()
    d = route_data[['route_id','veh']].set_index('route_id').to_dict()['veh']
    M =facility_data[['facility_id','capacity']].set_index('facility_id').to_dict()['capacity']
    c={}
    Name=list(deadhead_data.columns.values) 
    L=deadhead_data.to_dict()
    for fkey in Name:
        for rkey in L[fkey]:
            c[(rkey,fkey)]=L[fkey][rkey]
        
    from pyscipopt import Model,quicksum

    model = Model("transportation")
    x = {}
    for i in I:
        for j in J:
            x[i,j] = model.addVar(vtype="I", name="x(%s,%s)" % (i,j))
    for i in I:
        model.addCons(quicksum(x[i,j] for j in J if (i,j) in x) == d[i], name="Demand(%s)" % i)
    for j in J:
        model.addCons(quicksum(x[i,j] for i in I if (i,j) in x) <= M[j], name="Capacity(%s)" % j)
    model.setObjective(quicksum(c[i,j]*x[i,j]  for (i,j) in x), "minimize")
    model.optimize()
    print("Optimal value:", model.getObjVal())
    EPS = 1.e-6
    for (i,j) in x:
        if model.getVal(x[i,j]) > EPS:
            print("sending quantity %10s from route %3s to facility %3s" % (model.getVal(x[i,j]),i,j))
    for (i,j) in x:
        if model.getVal(x[i,j]) > EPS:
            print((model.getVal(x[i,j]),i,j))
            
    #(2) accumulated deadhead time
    accu_dh = pd.DataFrame(data = 0, index = deadhead_data.index, columns = deadhead_data.columns)
    # (3) veh allocation results
   #veh_asgn = np.zeros(deadhead_data.shape)
    veh_asgn = pd.DataFrame(data = 0, index = deadhead_data.index, columns = deadhead_data.columns)
        # (4) changes of vehicles left in each facility
    veh_left = facility_data.copy()
    veh_left = veh_left[["facility_id", "capacity"]]
    veh_left = veh_left.set_index('facility_id')
        # (5) changes of vehicles required for each routes
    veh_req = route_data.copy()
    veh_req = veh_req[["route_id", "veh"]]
    veh_req = veh_req.set_index('route_id')
        
    for (i,j) in x:
        if model.getVal(x[i,j]) > EPS:
            dh_value=deadhead_data.loc[i,[j]]
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
    veh_req = veh_req.reset_index()
    veh_left = veh_left.reset_index()

    print("final accumulated deadhead:", accu_dh.sum())
    return accu_dh, veh_asgn, veh_left, veh_req

def solve_or1(deadhead_data, facility_data):
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
    deadassign['deaddist_alloc']= deadassign.sum(axis=1)


    for index, row in deadassign.iterrows():
        for name in Name:
            if(row[name]>0):
                deadassign.at[index,'alloc_div']=name
    deadalloc = deadassign[['deaddist_alloc','alloc_div']]
    deadhead_data=deadhead_data.set_index('block_id')  

    ## joint deadhead_data to deadhead
    deadhead_data= deadhead_data.merge(deadalloc, on=['block_id'])  

    ## summarize the total for each facility
    facility_summary_exist=facilitysummary_existing(facility_data,deadhead_data)
    
    facility_summary_alloc=facilitysummary_realloc(facility_data,deadhead_data)
    
    
    print("final accumulated deadhead:", accu_dh.sum())
    return accu_dh, veh_asgn, veh_left, veh_req,facility_summary_exist,facility_summary_alloc
