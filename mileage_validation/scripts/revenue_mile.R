# NOTE : Run "data_cleaning.R" before running this script


##### Calculate revenue miles (use dist info in GTFS) #####
# note: not sure what the unit of shape_dist_traveled is, so use stop 57012 to 57014 as example to calculate the ratio
# shape_dist_traveled from 57012 to 57014 = 0.7607 - 0.5519 = 0.2088, which is about 0.131 miles
# 0.2088 / 0.131 = 1.59389312977
rev_mile_by_trip <- stop_times %>% 
                      group_by(trip_id) %>%
                      summarize(trip_revenue_mile = max(shape_dist_traveled, na.rm = TRUE) / 1.59389312977)

rev_mile_by_route <- rev_mile_by_trip %>%
                        left_join(trips, by = "trip_id") %>%
                        group_by(route_id) %>%
                        summarize(route_revenue_mile = sum(trip_revenue_mile)) %>%
                        # add real route number info
                        left_join(route, by = "route_id") %>%
                        select(route_id, route_short_name, route_long_name, route_revenue_mile)

## revenue mile comparison by route
# revenue mile info from tbest
rev_mile_tbest <- read.csv("data/revenue_mile_from_TBEST.csv") %>% select(Route, revenue_mile_tbest = Revenue_Service_Miles)

# revenue mile info from NTD index score
rev_mile_ind <- read.csv("data/revenue_mile_from_index_score.csv")
rev_mile_compare <- rev_mile_by_route %>% 
                      left_join(rev_mile_tbest, by = c("route_short_name" = "Route")) %>%
                      left_join(rev_mile_ind, by = c("route_short_name" = "Route")) %>%
                      rename(revenue_mile_gtfs = route_revenue_mile)

write.csv(rev_mile_compare, "output/rev_mile_compare.csv", row.names = FALSE)

