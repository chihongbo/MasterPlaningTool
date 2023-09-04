library(dplyr)
library(stringr)

setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

## Bus services
## Data: Aug 2018 Index Scores
input_service <- read.csv("data/bus_service.csv")

summary_service <- input_service %>% group_by(Div) %>%
                    summarize(num_routes = n(),
                              sum_peak_veh = sum(Peak.Vehicles),
                              sum_rev_mile = sum(Revenue.Miles),
                              sum_passengers = sum(Passengers)) %>%
                    mutate(rev_mile_share = sum_rev_mile / sum(sum_rev_mile))


## Facility division
## Data: Bus Fleet Maintenance Plan
## Bus fleet distribution
input_div_bus_id <- read.csv("data/division_fleet_bus_id.csv") %>%
                      mutate(Fuel = ifelse(str_detect(Make, "CNG"), "CNG", 
                                           ifelse(str_detect(Make, "Diesel"), "Diesel", "Others")))
input_div_fleet <- read.csv("data/division_fleet.csv") %>%
                      mutate(spare = total_fleet_size - peak_requirement,
                             spare_ratio = spare / total_fleet_size)

temp_total_fleet_by_fuel <- input_div_bus_id %>% group_by(Fuel) %>% 
                              summarize(Fuel_count = sum(Count))
  
summary_div_fleet_by_fuel <- input_div_bus_id %>% group_by(Div, Fuel) %>%
                              summarize(Count = sum(Count)) %>%
                              left_join(temp_total_fleet_by_fuel, by = "Fuel") %>%
                              mutate(Count_share = Count / Fuel_count)
rm(temp_total_fleet_by_fuel)


## ntd_rev_veh_inventory.csv
## Data: 2018 NTD (revenue vehicle inventory)
## Goal: calculate (1) annual miles by division by fuel type (2) annual miles distribution by division
input_ntd_rev_veh <- read.csv("data/ntd_rev_veh.csv")
input_ntd_rev_veh <- input_ntd_rev_veh[-3, ] # remove 3rd row for now <== question here
summary_annual_mile_by_div_fuel <- summary_div_fleet_by_fuel %>% left_join(input_ntd_rev_veh, by = "Fuel") %>%
                                      mutate(veh = Count_share * Vehicles,
                                             annual_mile = Count_share * Annual_Miles) %>%
                                      select(-c("Vehicles", "Annual_Miles")) %>%
                                      rename(Vehicle = veh,
                                             Annual_mile = annual_mile)
summary_annual_mile_by_div <- summary_annual_mile_by_div_fuel %>% group_by(Div) %>%
                                summarize(Annual_mile = sum(Annual_mile)) %>%
                                mutate(Annual_mile = ifelse(Div == "A", Annual_mile + 1071763, Annual_mile),
                                       Mile_share = Annual_mile / sum(Annual_mile))

## Data: 2018 NTD (service form)
## Goal: (1) distribute actual vehicle miles and actual revenue miles to each division
##       (2) calculate annual vehicle miles per peak vehicle
input_ntd_service <- read.csv("data/ntd_service.csv")

summary_actual_veh_mile_div <- summary_annual_mile_by_div %>%
                                mutate(weekday_veh_mile = Mile_share * input_ntd_service[input_ntd_service$Type == "Weekday", "Actual_Vehicle_Miles"],
                                       annual_veh_mile = Mile_share * input_ntd_service[input_ntd_service$Type == "Annual", "Actual_Vehicle_Miles"])
summary_actual_rev_mile_div <- summary_service %>%
                                mutate(weekday_rev_mile = rev_mile_share * input_ntd_service[input_ntd_service$Type == "Weekday", "Actual_Revenue_Miles"],
                                       annual_rev_mile = rev_mile_share * input_ntd_service[input_ntd_service$Type == "Annual", "Actual_Revenue_Miles"])
summary_actual_mile_div <- summary_actual_veh_mile_div %>% select(Div, Mile_share, weekday_veh_mile, annual_veh_mile) %>%
                              left_join(summary_actual_rev_mile_div, by = "Div") %>%
                              select(Div, num_routes, sum_peak_veh, sum_rev_mile, sum_passengers, rev_mile_share, weekday_rev_mile, annual_rev_mile, veh_mile_share = Mile_share, weekday_veh_mile, annual_veh_mile) %>%
                              mutate(annual_veh_mile_per_peak_veh = annual_veh_mile / sum_peak_veh)
rm(summary_actual_veh_mile_div, summary_actual_rev_mile_div)


