import pandas as pd

def cal_facility_util(scenario):
	# import input data
	facility_data = pd.read_csv(f'inputs/{scenario}/facility.csv')
	# import result data
	veh_left = pd.read_csv(f'outputs/{scenario}/result_veh_left.csv')

	# rename "capacity" in facility_data and veh_left data frame
	facility_data.rename(columns = {'capacity': 'pre-capacity'}, inplace = True)
	veh_left.rename(columns = {'capacity': 'post-capacity'}, inplace = True)
	result = pd.merge(facility_data, veh_left, on = 'facility_id')

	# calulate facility utilize ratio
	result[f'{scenario}'] =  (result['pre-capacity'] - result['post-capacity']) / result['pre-capacity']
	return result[['facility_id', f'{scenario}']]

def cal_facility_dh(scenario):
	# import result data
	accu_dh = pd.read_csv(f'outputs/{scenario}/result_accu_dh.csv', index_col = 0)
	return accu_dh.sum()

def cal_facility_busbay(scenario):
	# import result data
	accu_dh = pd.read_csv(f'outputs/{scenario}/result_accu_dh.csv', index_col = 0)
    accu_dh = pd.read_csv(f'outputs/{scenario}/Total_miles.csv', index_col = 0)
	return accu_dh.sum()


if __name__ == "__main__":
	# summary
	base = cal_facility_util('base')
	s1 = cal_facility_util('scenario_1')
	s2 = cal_facility_util('scenario_2')
	s3 = cal_facility_util('scenario_3')
	s4 = cal_facility_util('scenario_4')
	# merge all facility utilize % data frames
	dfs = [base, s1, s2, s3, s4]
	dfs = [df.set_index('facility_id', drop = True) for df in dfs]
	merged = pd.concat(dfs, axis = 1, keys = range(len(dfs)), join = 'outer', copy = False)
	merged.reset_index(drop = False, inplace = True)
	merged.columns = merged.columns.droplevel()
	merged = merged.rename(columns = {'': 'facility_id'})
	merged.to_csv('outputs/facility_util.csv', index = False)

	# base = cal_facility_dh('base')
	# s1 = cal_facility_dh('scenario_1')
	# s2 = cal_facility_dh('scenario_2')
	# s3 = cal_facility_dh('scenario_3')
	# s4 = cal_facility_dh('scenario_4')