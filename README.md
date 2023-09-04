# MasterPlaningTool
## Objective
Developing tool to assess maintenance facility of MARTA bus transit needs associated with system expansion
* Existing bus facilities evaluation/optimization
* Allocating buses for bus expansion 
* New facility site selection
## Improvements
* Calculating deadhead miles based on block
  * Original trip-based model detecting waiting time> 15 mins as deadhead 
  * New version can directly identify the deadhead for each block without explicit assumption from users
* Dynamically retrieving the street distance based on OSRM local server, instead of the original static method.
* Proposing a rigorous optimization model for bus allocation (block based), with the potential for site selection, comparing with original heuristic method.
* Integrating the bus bay utilization calculation in the model script from spreadsheet table.
## Methodology
![image](https://github.com/chihongbo/MasterPlaningTool/assets/4943641/1ec81b53-2ebb-43c8-9ea5-2a4e83e1498e)




