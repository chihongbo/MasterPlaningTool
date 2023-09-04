Below describes general steps to calculate deadhead miles


==== Part 1 - Count deadhead trips ====
Input: transit time table
Output: deadhead trip counts (between terminal stops and assigned facility) for each transit routes

Steps:

    from the time table, retrieve and sort each time point (bus departure/arrival)

    loop through each time point event

        update waiting time for all buses at bus stops
        send all buses that wait for more than 30 minutes back to facility ( ← deadhead trip)

        if the event represent bus departure
            if there is bus available at bus stop at that time
                assign a bus with shortest waiting time to this trip
            else
                ask for a bus from facility (← deadhead trip)
        else if the event represent bus arrival
            record bus arrival at bus stop

        Send all buses at bus stop back to facility ( ← deadhead trips at the end of the day)


==== Part 2 - Geoprocessing ====
Current tool: OSM routing

For all the terminal stop - facility pair found in the previous step, calculate shortest path mileage using GIS tool

==== Part 3 - Final calculation ====
Table join the results from previous 2 parts and perform final summary calculation.

Total deadhead mileage = deadhead counts * deadhead miles
