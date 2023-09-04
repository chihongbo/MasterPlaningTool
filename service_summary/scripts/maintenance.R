library(dplyr)
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
## Annual Schedule Services per Vehicle
## (import summary result "summary_actual_mile_div")
summary_annual_schedule_service <- summary_actual_mile_div %>% 
        mutate(## annual schedule services per vehicle
               veh_inspection_per_year = annual_veh_mile_per_peak_veh / 6000,
               veh_engine_tune_up = annual_veh_mile_per_peak_veh / 36000,
               veh_midlife_overhaul = annual_veh_mile_per_peak_veh / 250000,
               ## annual schedule services per facility
               fac_inspection_per_year = sum_peak_veh * veh_inspection_per_year,
               fac_engine_tune_up = sum_peak_veh * veh_engine_tune_up,
               fac_midlife_overhaul = sum_peak_veh * veh_midlife_overhaul,
               ## extra input <=  add this to previous part
               num_bay = c(20, 19, 16),
               ## annual schedule services per bay
               bay_inspection_per_year = fac_inspection_per_year / num_bay,
               bay_engine_tune_up = fac_engine_tune_up / num_bay,
               bay_total_service = bay_inspection_per_year + bay_engine_tune_up,
               ## Scheduled Maintenance Utilization (assume 250 working days per year)
               schedule_utilization = bay_total_service / 250,
               ## unscheduled maintenance - predicted annual major mechanical failures per division 
               ## (assume 264 major mechanical failures per million vehicle miles)
               major_failure = annual_veh_mile * 264 / 1000000,
               ## predicted annual major mechanical failures at division facility
               divfac_major_failure_divfac = major_failure * 0.5,
               divfac_bay_major_failure = divfac_major_failure_divfac / num_bay,
               ## total maintenance bay demand
               bay_maintenance_demand = bay_total_service + divfac_bay_major_failure,
               ## overall maintenance utilization (assume 250 working days per year)
               utilization = bay_maintenance_demand / 250)


write.csv(summary_annual_schedule_service, "summary_annual_schedule_service.csv", row.names = FALSE)
