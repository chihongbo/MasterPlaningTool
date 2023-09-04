library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(foreign)
library(geosphere)
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
##### Load MARTA GTFS data #####
#shapes <- read.csv("data/MARTA_GTFS/shapes.txt") %>% select(shape_id, shape_pt_sequence,shape_dist_traveled)%>% 
#       rename(seq=shape_pt_sequence, dist=shape_dist_traveled)%>%
#       group_by(shape_id) %>% summarize(distance = max(dist))%>%
#       mutate(distance= distance/1.59389312977)
shapes2 <- read.csv("data/MARTA_GTFS/shapes.txt") %>% select(shape_id, shape_pt_lat,shape_pt_lon,shape_pt_sequence)%>% rename(seq=shape_pt_sequence,lat=shape_pt_lat,lon=shape_pt_lon) %>%
  arrange(shape_id, seq) %>% mutate(dist= 0.0000)

for(i in 1:nrow(shapes2)){
  #tempstr<-paste(block_timetable_df2$start_stop[i],block_timetable_df2$start_div[i])
  if(shapes2$seq[i]==1){
    shapes2$dist[i]<- 0

  }else{
    lon1<-shapes2$lon[i-1]
    lat1<-shapes2$lat[i-1]
    lon2<-shapes2$lon[i]
    lat2<-shapes2$lat[i]
    shapes2$dist[i]<- shapes2$dist[i-1]+distm(c(lon1, lat1), c(lon2, lat2), fun = distHaversine)/1000.0/1.60934
  }
}
shapes<-shapes2 %>% group_by(shape_id) %>% summarize(distance = max(dist))


facility<- read.csv("data/facility_location.csv")

stops<- read.csv("data/MARTA_GTFS/stops.txt")%>%
  select(stop_id,stop_lat,stop_lon)

stops<-stops[, c("stop_id","stop_lon","stop_lat")]

route <- read.csv("data/MARTA_GTFS/routes.txt") %>% 
            filter(route_type == 3) %>% # select only bus routes
            mutate(route_short_name= as.numeric(as.character(route_short_name))) %>% # convert data type from factor to numeric
            select(route_id, route_short_name, route_long_name) %>%
            arrange(route_short_name)
trips <- read.csv("data/MARTA_GTFS/trips.txt") %>% 
          filter((route_id %in% route$route_id) & (service_id == 5)) %>% # select only bus trips & only weekday trips (service_id = 5)
          select(route_id, trip_id, direction_id,block_id,shape_id) %>% ## left join the trip distance
          left_join(shapes, by = "shape_id")
  
stop_times <- read.csv("data/MARTA_GTFS/stop_times.txt") %>%
                filter(trip_id %in% trips$trip_id) %>% # select only bus trips
                # data cleaning - convert arrival and departure time to time format
                # (Note: the new format will include "current date", however, only the relative date is meaningful)
                separate(arrival_time, c("aH", "aM", "aS"), ":", extra = "merge") %>% # put hour/min/sec in seperate columns
                separate(departure_time, c("dH", "dM", "dS"), ":", extra = "merge") %>%
                mutate(aOver = ifelse(as.numeric(aH) >= 24, 1, 0), # inticator of arrival time at/after 24:00
                       aH = ifelse(aOver == 1, as.character(as.numeric(aH) - 24), aH),
                       aH = str_pad(aH, 2, side = "left", pad = "0"),
                       dOver = ifelse(as.numeric(dH) >= 24, 1, 0), # inticator of departure time at/after 24:00
                       dH = ifelse(dOver == 1, as.character(as.numeric(dH) - 24), dH),
                       dH = str_pad(dH, 2, side = "left", pad = "0"),
                       arrival_time_chr = paste(aH, aM, aS, sep = ":"),
                       departure_time_chr = paste(dH, dM, dS, sep = ":"),
                       arrival_time = as.POSIXct(strptime(arrival_time_chr, format = "%H:%M:%S")),
                       departure_time = as.POSIXct(strptime(departure_time_chr, format = "%H:%M:%S"))) %>%
                select(trip_id, arrival_overnight = aOver, departure_overnight = dOver, arrival_time, departure_time, stop_id, stop_sequence)
# if trip start or end overnight (>= 24 hr), then add 1 day to arrival_time / departure_time
stop_times$arrival_time[stop_times$arrival_overnight == 1] <- stop_times$arrival_time[stop_times$arrival_overnight == 1] + lubridate::days(1)
stop_times$departure_time[stop_times$departure_overnight == 1] <- stop_times$departure_time[stop_times$departure_overnight == 1] + lubridate::days(1)

divisions1<- read.csv("data/divisions.csv") 
divisions<-route%>%
  left_join(divisions1,by=c("route_short_name"="route_no")) %>%
  rename(route_id=route_id.x, route_no=route_short_name)%>%
  select(route_id, route_no, division)%>% 
  replace_na(list(division= "A"))
  
  
  #mutate_each(funs(replace(., which(is.na(.)), "A")))
