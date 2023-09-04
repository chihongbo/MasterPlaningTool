# NOTE : Run "data_cleaning.R" before running this script
library(foreign)
library(timechange)
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
# add directional info to stop_times

#route_timetable1 <- route_timetable%>% 
#  mutate(ActBus=0)

#for(id in route$route_id){
#id<-12768
#if(id == 12768){
  print(paste("process route: ", id, sep = ""))
  
  route_timetable <- route_timetable %>% 
                      mutate(ActBus = 0)

  
  for(i in 1:nrow(route_timetable)){

     current_stime <- route_timetable$start_time[i]

     actbus1=1
     for(i1 in i:1){
       old_stime <- route_timetable$start_time[i1]
       old_etime <- route_timetable$end_time[i1]
       old_swait <- route_timetable$start_wait[i1]       
       old_stime<-time_subtract(old_stime, minutes = old_swait)
       
       if(current_stime>old_stime & current_stime<old_etime & i1!=i){
         actbus1=actbus1+1
       }
       
     }
     route_timetable$ActBus[i]=actbus1
  }
#}

