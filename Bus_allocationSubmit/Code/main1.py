import pandas as pd
import numpy as np
from solver import *

def run_scenario(scenario):
	# import data
	deadhead_data = pd.read_csv(f'inputs/{scenario}/ALL_deadhead_dist_4.csv')
	facility_data = pd.read_csv(f'inputs/{scenario}/facility_location.csv')
	#route_data = pd.read_csv(f'inputs/{scenario}/route.csv')
    #print(facility_data)
	# check deadhead time based on route type
	#route_data.loc[route_data["route_type"] == "L", "max_deadhead"] = 30
	#route_data.loc[route_data["route_type"] == "E", "max_deadhead"] = 50
	# print(route_data)
	#max_dh = deadhead_data.ge(route_data["max_deadhead"], axis=0) # A boolean dataframe. "True" if not meeting the deadhead requirement.
	# print(max_dh)
	#deadhead_data[max_dh] = np.nan
	#print(deadhead_data)

	# test delete route (delete route type == LR or HR, only keep route type == L or E)
	#route_data, deadhead_data = del_route(route_data, 'ASC A Line', deadhead_data)
	#route_data, deadhead_data = del_route(route_data, 'BLUE', deadhead_data)
	#route_data, deadhead_data = del_route(route_data, 'GOLD', deadhead_data)
	#route_data, deadhead_data = del_route(route_data, 'GREEN', deadhead_data)
	#route_data, deadhead_data = del_route(route_data, 'RED', deadhead_data)
    #print(route_data)
    #print(deadhead_data)
    #print(facility_data)

	# run bus allocation solver
	accu_dh, veh_asgn, veh_left, veh_req, facility_summary_exist,facility_summary_alloc = solve_or1(deadhead_data, facility_data)

	# reset index accu_dh and veh_asgn for export purpose
	accu_dh.reset_index(level = 0, inplace = True)
	accu_dh.rename(columns = {'index': 'route_id'}, inplace = True)
	veh_asgn.reset_index(level = 0, inplace = True)
	veh_asgn.rename(columns = {'index': 'route_id'}, inplace = True)

	# save results to csv files
	accu_dh.to_csv(f'outputs/{scenario}/result_accu_dh.csv', index = False)
	veh_asgn.to_csv(f'outputs/{scenario}/result_veh_asgn.csv', index = False)
	veh_left.to_csv(f'outputs/{scenario}/result_veh_left.csv', index = False)
	veh_req.to_csv(f'outputs/{scenario}/result_veh_req.csv', index = False)
	facility_summary_exist.to_csv(f'outputs/{scenario}/facility_summary_exist.csv', index =True)
	facility_summary_alloc.to_csv(f'outputs/{scenario}/facility_summary_reallocate.csv', index = True)

if __name__ == "__main__":
	#run_scenario('base')
	#run_scenario('scenario_1')
	#run_scenario('scenario_2')
	#run_scenario('scenario_3')
	run_scenario('scenario_4')
	