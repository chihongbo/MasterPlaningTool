# NOTE : Run "data_cleaning.R" before running this script
library(foreign)
library(timechange)
library(timevis)
library(hash)
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
source("OSM_Distance_function.R")
# add directional info to stop_times
h <- hash() ## delcare an empty hash set for internal deadpoint
h1 <- hash() ## delcare an empty hash set for stat or end deadhead

#s2s_mid<- read.csv("data/Mid_deadhead_dist.csv")
#s2s_mid$mile<-s2s_mid$distance/1000/1.60934  # convert the distance to miles
#s2s_mid$DURATION_H<-s2s_mid$duration/3600.0  # convert the second to hours

shortest <- unique(read.dbf("data/shortest_path_all.dbf") %>% select(FROM_ID, TO_ID, mile,DURATION_H))

stop_times1 <- stop_times %>% 
                left_join(trips, by = "trip_id")
  
#stop_times<-stop_times1
# find largest stop sequence number of each trip
largest_trip_seq <- stop_times1 %>% group_by(trip_id) %>% summarize(last_stop_sequence = max(stop_sequence))

# find start & end time of each trip
# note: since arrival time & departure time are the same in MARTA GTFS, 
#       use arrival time to represent the time bus at each stop

trip_terminal_times <- stop_times1 %>% 
                        left_join(largest_trip_seq, by = "trip_id") %>%
                        filter(stop_sequence == 1 | stop_sequence == last_stop_sequence) %>%
                        mutate(stop_type = ifelse(stop_sequence == 1, "start", "end")) %>%
                        select(route_id, trip_id, direction_id, block_id,distance,stop_id, stop_type,
                               overnight = arrival_overnight, time = arrival_time) %>%
                        pivot_wider(names_from = stop_type, values_from = c(stop_id, overnight, time)) %>%
                        rename(start_stop = stop_id_start, end_stop = stop_id_end,
                               start_overnight = overnight_start, end_overnight = overnight_end,
                               start_time = time_start, end_time = time_end) %>%
                        arrange(route_id, start_time)


start_deadhead_df <- data.frame(route_id = integer(),
                                start_stop = integer(),
                                start_deadhead = integer())
end_deadhead_df <- data.frame(route_id = integer(),
                              end_stop = integer(),
                              end_deadhead = integer())

start_deadhead_df1 <- data.frame(route_id = integer(),
                                 division=character(),
                                 start_stop = integer(),
                                 start_deadhead = integer())
end_deadhead_df1 <- data.frame(route_id = integer(),
                               division=character(),
                               end_stop = integer(),
                               end_deadhead = integer())
mid_deadhead_df1 <- data.frame(route_id = integer(),
                              start_stop = integer(),
                              deaddist_mid=double())

route_timetable_df <- data.frame(route_id = integer(),
                                trip_id = integer(),
                                direction_id=integer(), 
                                block_id=integer(),
                                distance=double(),
                                time=double(),
                                start_stop=integer(), 
                                end_stop=integer(),
                                start_time=POSIXct(), 
                                end_time=POSIXct(),
                                division=character(),
                                dead_code= integer(),
                                deaddist_mid=double(),
                                deaddist_start=double(),
                                deaddist_end=double(),
                                deadtime_mid=double(),
                                deadtime_start=double(),
                                deadtime_end=double(),
                                start_deadhead = integer(),
                                end_deadhead = integer(),
                                mid_deadhead = integer(),
                                start_wait=integer()
                                ) 

block_timetable_df <- data.frame(block_id=integer(),
                                 startroute_id=integer(),
                                 endroute_id=integer(),
                                 start_stop=integer(), 
                                 end_stop=integer(),
                                 start_time=POSIXct(), 
                                 end_time=POSIXct(),
                                 deaddist_start=double(),
                                 deaddist_mid=double(),
                                 deaddist_end=double(),
                                 deadtime_start=double(),
                                 deadtime_mid=double(),
                                 deadtime_end=double(),
                                 time=double(),
                                 distance=double(),
                                 start_div=character(),
                                 end_div=character()
) 

s2s_midpair <- data.frame(start_stop=integer(), 
                          end_stop=integer()
) 


fileConn<-file("output/warning.txt",open = "wt")


for(id in route$route_id){
#id<-12768
#if(id == 12768){
  print(paste("process route: ", id, sep = ""))
  
  route_timetable <- trip_terminal_times %>% 
                      filter(route_id == id) %>%
                      mutate(bus_num_id = 0,
                             start_deadhead = 0,
                             end_deadhead = 0,
                             start_wait=0,
                             end_wait=0,
                             tripcon_id=0,
                             tripcomp_id=0)
  
  sorted_times <- stop_times1 %>% 
                    left_join(largest_trip_seq, by = "trip_id") %>%
                    filter(stop_sequence == 1 | stop_sequence == last_stop_sequence) %>%
                    mutate(stop_type = ifelse(stop_sequence == 1, "start", "end")) %>%
                    select(route_id, trip_id, direction_id, stop_id, stop_type,
                           overnight = arrival_overnight, time = arrival_time) %>%
                    arrange(route_id, time, stop_type) %>%
                    filter(route_id == id)
  
  bus_available <- data.frame(route_id = integer(),
                              trip_id = integer(),
                              stop_id = integer(), 
                              bus_num_id = integer(), 
                              available_time = POSIXct(),
                              wait_time = POSIXct()) 
  
  next_bus_num_id <- 1
  
  for(i in 1:nrow(sorted_times)){
     print(paste("row num: ", i, sep = ""))
    current_route_id <- sorted_times$route_id[i]
    current_trip_id <- sorted_times$trip_id[i]
    current_stop_id <- sorted_times$stop_id[i]
    current_stop_type <- sorted_times$stop_type[i]
    current_time <- sorted_times$time[i]
     print(paste("route_id: ", current_route_id, sep = ""))
     print(paste("trip_id: ", current_trip_id, sep = ""))
     print(paste("stop_id: ", current_stop_id, sep = ""))
     print(paste("stop_type: ", current_stop_type, sep = ""))
    
    # update wait time (if there is any bus available at any stop)
    if(nrow(bus_available) > 0){
       print("before update wait time")
       print(bus_available)
      bus_available$wait_time <- current_time - bus_available$available_time
       print("update wait time")
      # if wait time > 30 min -> send bus back
      return_bus <- bus_available[bus_available$wait_time > lubridate::minutes(30), ]
      
      if(nrow(return_bus) > 0){
         print("bus wait too long!!!")
         print(return_bus)
        for(i1 in 1:nrow(return_bus)){
         route_timetable[(route_timetable$route_id == return_bus$route_id[i1] & route_timetable$trip_id == return_bus$trip_id[i1]), ]$end_deadhead <- 1
         route_timetable[(route_timetable$route_id == return_bus$route_id[i1] & route_timetable$trip_id == return_bus$trip_id[i1]), ]$end_wait <- as.numeric(return_bus$wait_time, units = "mins")[i1]
         route_timetable[(route_timetable$route_id == return_bus$route_id[i1] & route_timetable$trip_id == return_bus$trip_id[i1]), ]$tripcomp_id <- current_trip_id

        }
        bus_available <- bus_available[bus_available$wait_time <= lubridate::minutes(30), ]  ## update the bus_available table
      }
       print(bus_available)
       print("-----")
      
    }
    
    
    if(current_stop_type == "start"){ # need a bus from start stop
      # print(paste("need a bus from stop: ", current_stop_id, sep = ""))
      # if there is no bus available at start stop
      # print(paste("nrow(bus_available): ", nrow(bus_available), sep = ""))
      # print(paste("bus_available$stop_id: ", bus_available$stop_id), sep = "")
      if(nrow(bus_available) == 0 | !(current_stop_id %in% bus_available$stop_id)){
        # print(paste("no bus available at stop: ", current_stop_id, sep = ""))
        # assign bus number id
        # print(paste("new bus id created: ", next_bus_num_id, sep = ""))
        route_timetable[(route_timetable$route_id == current_route_id & route_timetable$trip_id == current_trip_id), ]$bus_num_id <- next_bus_num_id
        # require deadhead trip
        # print(paste("deadhead trip to stop: ", current_stop_id, sep = ""))
        route_timetable[(route_timetable$route_id == current_route_id & route_timetable$trip_id == current_trip_id), ]$start_deadhead <- 1 ## if no available bus at the station, then this trip should request a bus from the facility
        # accumulate bus number id
        next_bus_num_id <- next_bus_num_id + 1
      } else { # if bus available at start stop
        # find bus with shortest waiting time that can serve the trip
        selected_bus <- bus_available[bus_available$route_id == current_route_id & bus_available$stop_id == current_stop_id, ] %>%
                          arrange(wait_time) %>%
                          tail(1)
        # print(paste("bus available: ", selected_bus$bus_num_id))
        # assign bus number id
        route_timetable[(route_timetable$route_id == current_route_id & route_timetable$trip_id == current_trip_id), ]$bus_num_id <- selected_bus$bus_num_id
        route_timetable[(route_timetable$route_id == current_route_id & route_timetable$trip_id == current_trip_id), ]$start_wait <- as.numeric(selected_bus$wait_time, units = "mins")
        route_timetable[(route_timetable$route_id == current_route_id & route_timetable$trip_id == current_trip_id), ]$tripcon_id <- selected_bus$trip_id
        # remove the selected bus from bus_available data frame
        if(as.numeric(selected_bus$wait_time)>1000){
          print(current_trip_id)
          print(current_time)
          print("very large waiting time!!")
          print(bus_available)
          bus_available1<-bus_available
          #readline("Wrong waiting time")
        }
        
        bus_available <- bus_available %>% filter(bus_num_id != selected_bus$bus_num_id)
        # print("bus used, remaining bus available:")
        # print(bus_available)
      }
    } else { # if current_stop_type == "end" -> add the bus to bus_available data frame
      # find bus_num_id
      current_bus_num_id <- route_timetable[(route_timetable$route_id == current_route_id & route_timetable$trip_id == current_trip_id), ]$bus_num_id
      # print(paste("trip end for bus num: ", current_bus_num_id, sep = ""))
      bus_available <- rbind(bus_available, data.frame(route_id = current_route_id,
                                                       trip_id = current_trip_id,
                                                       stop_id = current_stop_id, 
                                                       bus_num_id = current_bus_num_id, 
                                                       available_time = current_time, 
                                                       wait_time = current_time - current_time))
      # print("update bus_available:")
      # print(bus_available)
    }
    # print("===========")
    
  }
  
  # send all the remaining bus back to facility
  route_timetable[route_timetable$route_id %in% bus_available$route_id & route_timetable$trip_id %in% bus_available$trip_id, ]$end_deadhead <- 1
  #route_timetable[route_timetable$route_id %in% bus_available$route_id & route_timetable$trip_id %in% bus_available$trip_id, ]$end_wait <- as.numeric(bus_available$wait_time)
  # create deadhead count summary
  start_deadhead_count <- route_timetable %>% group_by(route_id, start_stop) %>% summarize(start_deadhead = sum(start_deadhead))
  start_deadhead_df <- rbind(start_deadhead_df, data.frame(start_deadhead_count))
  end_deadhead_count <- route_timetable %>% group_by(route_id, end_stop) %>% summarize(end_deadhead = sum(end_deadhead))
  end_deadhead_df <- rbind(end_deadhead_df, data.frame(end_deadhead_count))
  
  ###################################################################################################
  ### the following part are added by Hongbo for creating Gannte graph for each route based on block#
  ###################################################################################################
  route_timetable <- route_timetable %>% 
    mutate(ActBus = 0)
  
  
  for(i in 1:nrow(route_timetable)){
    
    current_stime <- route_timetable$start_time[i]
    
    actbus1=0
    bus_list<-list()## trip_id list
    for(i1 in i:1){
      bus_id<-route_timetable$bus_num_id[i1]
      start_deadhead<-route_timetable$start_deadhead[i1]
      end_deadhead<-route_timetable$end_deadhead[i1]
      
      old_stime <- route_timetable$start_time[i1]
      old_etime <- route_timetable$end_time[i1]
      old_swait <- route_timetable$start_wait[i1]  
      old_ewait <- route_timetable$end_wait[i1]
      old_stime<-time_subtract(old_stime, minutes = old_swait)
      
      if(bus_id %in% bus_list){next}
      bus_list <- append(bus_list, bus_id)
      
      if(current_stime>=old_stime & current_stime<=old_etime|| end_deadhead==0){
        actbus1=actbus1+1
      }
      
    }
    route_timetable$ActBus[i]=actbus1
  }
  
  
  uniblock<-unique(route_timetable[c('block_id')], by=c('block_id'))
  route_timetable_1<-route_timetable
  for(i in 1:nrow(uniblock)){ 
    block_id1=uniblock$block_id[i]
    route_timetable_sel <- trip_terminal_times %>% 
      filter(block_id == block_id1 & route_id!=id) %>%
      mutate(bus_num_id = 0,
             start_deadhead = 0,
             end_deadhead = 0,
             start_wait=0,
             end_wait=0,
             tripcon_id=0,
             tripcomp_id=0,
             ActBus=0)
    route_timetable_1 <- rbind(route_timetable_1, route_timetable_sel)
    
  }
  
  vec<-1:nrow(uniblock)
  uniblock$order<-vec
  route_timetable_1 <- route_timetable_1 %>% 
    left_join(uniblock, by = "block_id")
  route_timetable_1 <- route_timetable_1 %>%
    arrange(order, start_time)
  block_seq <- route_timetable_1 %>% group_by(block_id) %>% summarize(start_time = min(start_time),end_time = max(end_time)) %>% arrange(start_time)  # block seq for all routes
  block_seq_1 <- route_timetable_1 %>%  filter(route_id == id) %>% group_by(block_id) %>% summarize(start_time = min(start_time),end_time = max(end_time)) %>% arrange(start_time) # block seq for the same route

    
  # data <- data.frame(
  #   id      = 1:nrow(block_seq_1),
  #   content = block_seq_1$block_id,
  #   start   = block_seq_1$start_time,
  #   end     = block_seq_1$end_time,
  #   title   = paste(id, block_seq_1$start_time, block_seq_1$end_time)
  # )
  # 
  # tv<-timevis(data,fit = TRUE)
  # 
  # htmltools::html_print(tv)
  # file=gsub(" ", "", paste("Route_blockgrpah_",toString(id),".html"))
  # htmltools::save_html(tv, file, background = "white",libdir = "lib")
  # file=gsub(" ", "", paste("output/block_seq_",toString(id),".csv"))
  # write.csv(block_seq_1, file, row.names = FALSE)
  # file=gsub(" ", "", paste("output/Route_TT_",toString(id),".csv"))
  # write.csv(route_timetable_1, file, row.names = FALSE)
  
  
  ###############################################################################################################################
  ### the following script part is used by Hongbo to construct new route_timeTable based on the block # instead of waiting time
  ###############################################################################################################################
  
  route_timetable_2 <- data.frame(route_id = integer(),
                              trip_id = integer(),
                              direction_id=integer(), 
                              block_id=integer(),
                              distance=double(),
                              time=double(),
                              start_stop=integer(), 
                              end_stop=integer(),
                              start_time=POSIXct(), 
                              end_time=POSIXct(),
                              dead_code= integer(),
                              deaddist_mid=double(),
                              deaddist_start=double(),
                              deaddist_end=double(),
                              deadtime_mid=double(),
                              deadtime_start=double(),
                              deadtime_end=double(),
                              start_deadhead = integer(),
                              end_deadhead = integer(),
                              mid_deadhead = integer(),
                              start_wait=integer(),
                              division=character()) 
  for(i in 1:nrow(block_seq)){   ## update the selected block information drop the old deadhead infor and add new deadhead infor and division information
  #block_id1=966682
  #if(block_id1==966682){
    block_id1=block_seq$block_id[i]
    block_seq_2<-route_timetable_1%>%
      left_join(divisions,by="route_id")%>%
      filter(block_id==block_id1) %>%
      select(route_id, trip_id, direction_id, block_id,distance,start_stop, end_stop,start_time, end_time,division)%>%  
      mutate(time=0,
             dead_code= 0,
             deaddist_mid=0,
             deaddist_start=0,
             deaddist_end=0,
             deadtime_mid=0,
             deadtime_start=0,
             deadtime_end=0,
             start_deadhead = 0,
             end_deadhead = 0,
             mid_deadhead = 0,
             start_wait=0)
    for(j in 1:nrow(block_seq_2)){
      block_seq_2$time[j]=as.numeric(block_seq_2$end_time[j]-block_seq_2$start_time[j], units = "hours")
      if(j==1){  ## start of the block
        block_seq_2$dead_code[j]=1
        block_seq_2$start_deadhead[j]=1
        Temp<-shortest%>%filter(FROM_ID == block_seq_2$start_stop[j], TO_ID == block_seq_2$division[j])
        block_seq_2$deaddist_start[j]=Temp$mile[1]
        block_seq_2$deadtime_start[j]=Temp$DURATION_H[1]
      }
      if(j==nrow(block_seq_2)){  ## end of the block
        block_seq_2$dead_code[j]=2
        block_seq_2$end_deadhead[j]=1
        Temp<-shortest%>%filter(FROM_ID == block_seq_2$end_stop[j], TO_ID == block_seq_2$division[j])
        block_seq_2$deaddist_end[j]=Temp$mile[1]
        block_seq_2$deadtime_end[j]=Temp$DURATION_H[1]
      }
      if(j>1){
        block_seq_2$start_wait[j]= as.numeric(block_seq_2$start_time[j]- block_seq_2$end_time[j-1], units = "mins")
        if(block_seq_2$division[j]!=block_seq_2$division[j-1]){       ## division warning message if the same block has route belonging to different divisions
          writeLines(paste(id,block_seq_2$block_id[j],block_seq_2$trip_id[j],block_seq_2$division[j],"the previous trip return to a different division"), fileConn)
          
        }
        
        if(block_seq_2$start_stop[j]!=block_seq_2$end_stop[j-1]){ ## disconnected trips for in the same block, need to add the empty bus run to the new start point midhead situation
           block_seq_2$dead_code[j]=3           #inroute deadheadhead for same route
           block_seq_2$mid_deadhead[j]=1
           #Temp<-s2s_mid%>%filter(start_stop == block_seq_2$end_stop[j-1], end_stop == block_seq_2$start_stop[j])
           tempstr<-paste(block_seq_2$end_stop[j-1],block_seq_2$start_stop[j])
           if(is.null(h[[tempstr]])){
             skim<-distance2point(list(block_seq_2$end_stop[j-1],block_seq_2$start_stop[j]))
             block_seq_2$deaddist_mid[j]=skim[1]  
             block_seq_2$deadtime_mid[j]=skim[2]         
             h[[tempstr]]<-skim
           }else{
             block_seq_2$deaddist_mid[j]=h[[tempstr]][1]  
             block_seq_2$deadtime_mid[j]=h[[tempstr]][2]
           }
           
           #block_seq_2$deaddist_mid[j]=Temp$mile[1]  
           #block_seq_2$deadtime_mid[j]=Temp$DURATION_H[1]
           writeLines(paste(id,block_seq_2$block_id[j],block_seq_2$trip_id[j],block_seq_2$end_stop[j-1],block_seq_2$start_stop[j]), fileConn,sep = "\n") ## output the identifed varaible
           s2s_midtemp<-data.frame(start_stop=block_seq_2$end_stop[j-1],end_stop=block_seq_2$start_stop[j])
           s2s_midpair<-rbind(s2s_midpair,  s2s_midtemp)

        }
      }
      
    }
    route_timetable_2<- rbind(route_timetable_2, block_seq_2)
    j<-nrow(block_seq_2)
    if(!block_id1 %in% block_timetable_df$block_id){
       block_temp_df <- data.frame(block_id=block_id1,
                                startroute_id=block_seq_2$route_id[1],
                                endroute_id=block_seq_2$route_id[j],
                                start_stop=block_seq_2$start_stop[1], 
                                end_stop=block_seq_2$end_stop[j],
                                start_time=block_seq_2$start_time[1], 
                                end_time=block_seq_2$end_time[j],
                                deaddist_start=sum(block_seq_2$deaddist_start, na.rm = TRUE),
                                deaddist_mid=sum(block_seq_2$deaddist_mid, na.rm = TRUE),
                                deaddist_end=sum(block_seq_2$deaddist_end, na.rm = TRUE),
                                deadtime_start=sum(block_seq_2$deadtime_start, na.rm = TRUE),
                                deadtime_mid=sum(block_seq_2$deadtime_mid, na.rm = TRUE),
                                deadtime_end=sum(block_seq_2$deadtime_end, na.rm = TRUE),
                                time=as.numeric(block_seq_2$end_time[j]-block_seq_2$start_time[1],units = "hours")-sum(block_seq_2$deadtime_mid, na.rm = TRUE), 
                                distance=sum(block_seq_2$distance, na.rm = TRUE),
                                start_div=block_seq_2$division[1],
                                end_div=block_seq_2$division[j]

         ) 
    
         block_timetable_df<- rbind(block_timetable_df, block_temp_df)
    }
  }
  file=gsub(" ", "", paste("output/Route_TT2_",toString(id),".csv"))
  write.csv(route_timetable_2, file, row.names = FALSE)
  
  route_timetable_3<-route_timetable_2%>%filter(route_id==id)  ## timetable_2 is the one contain all the routes for the same block timetable_3 contain only the same route for the same block time table
  route_timetable_df<- rbind(route_timetable_df, route_timetable_3)
}

close(fileConn) ## output warnning message on the abnormal situation
write.csv(start_deadhead_df, "output/start_deadhead_df.csv", row.names = FALSE)
write.csv(end_deadhead_df, "output/end_deadhead_df.csv", row.names = FALSE)

# left joint the node lat and long information to s2s_midpair
s2s_midpair<-unique(s2s_midpair[c("start_stop","end_stop")], by=c("start_stop","end_stop"))
s2s_midpair <- s2s_midpair %>%   ## join to the long and lat information to this pair
  left_join(stops, by = ( c("start_stop" = "stop_id"))) %>% select(start_stop,end_stop,stop_lon,stop_lat)%>% 
  rename(FLong=stop_lon, FLat=stop_lat)%>%
  left_join(stops, by = ( c("end_stop" = "stop_id"))) %>% select(start_stop,end_stop,FLong,FLat,stop_lon,stop_lat)%>% 
  rename(TLong=stop_lon, TLat=stop_lat)

# left joint the node lat and long information to block_timetable_df
#s2s_midpair<-unique(s2s_midpair[c("start_stop","end_stop")], by=c("start_stop","end_stop"))

block_timetable_df1 <- block_timetable_df %>%   ## join to the long and lat information to this pair
  left_join(stops, by = ( c("start_stop" = "stop_id"))) %>% select(block_id,startroute_id,endroute_id,start_stop,end_stop,start_time, end_time,deaddist_start,deaddist_mid,deaddist_end,deadtime_start,deadtime_mid,deadtime_end,time,distance,start_div,end_div,stop_lon,stop_lat)%>% 
  rename(SLong=stop_lon, SLat=stop_lat)%>%
  left_join(stops, by = ( c("end_stop" = "stop_id"))) %>% select(block_id,startroute_id,endroute_id,start_stop,end_stop,start_time, end_time,deaddist_start,deaddist_mid,deaddist_end,deadtime_start,deadtime_mid,deadtime_end,time,distance,start_div,end_div,SLong,SLat,stop_lon,stop_lat)%>% 
  rename(ELong=stop_lon, ELat=stop_lat)%>%
  left_join(facility, by = ( c("end_div" = "FT_Alias"))) %>% select(block_id,startroute_id,endroute_id,start_stop,end_stop,start_time, end_time,deaddist_start,deaddist_mid,deaddist_end,deadtime_start,deadtime_mid,deadtime_end,time,distance,start_div,end_div,SLong,SLat,ELong,ELat,FTLong,FTLat) 




# extract unique deadhead pairs
#start_deadhead_pair <- unique(start_deadhead_df %>% select(stop = start_stop, Div))
#end_deadhead_pair <- unique(end_deadhead_df %>% select(stop = end_stop, Div))
#unique_deadhead_pair <- unique(rbind(start_deadhead_pair, end_deadhead_pair)) %>% arrange(Div, stop)

#write.csv(unique_deadhead_pair, "output/unique_deadhead_pair.csv", row.names = FALSE)

##### Intermediate step using GIS - shortest path distance calculation #####

# deadhead mile calculation
#shortest <- unique(read.dbf("data/shortest_path_all.dbf") %>% select(FROM_ID, TO_ID, mile))
route_info <- read.dbf("data/bus_routes.dbf") %>% select(short_name, long_name, Div, GARAGE, mile)
route_info$short_name <- as.numeric(as.character(route_info$short_name))
route_depot <- unique(route_info %>% select(short_name, long_name, Div)) %>%
                arrange(short_name) %>%
                left_join(route, by = c("short_name" = "route_short_name"))

start_deadhead_df <- start_deadhead_df %>% 
                      left_join(route_depot, by = "route_id") %>%
                      left_join(shortest, by = c("start_stop" = "FROM_ID", "Div" = "TO_ID")) %>%
                      mutate(deadhead_mile = start_deadhead * mile)
  
end_deadhead_df <- end_deadhead_df %>% 
                      left_join(route_depot, by = "route_id") %>%
                      left_join(shortest, by = c("end_stop" = "FROM_ID", "Div" = "TO_ID")) %>%
                      mutate(deadhead_mile = end_deadhead * mile)

total_deadhead <- sum(start_deadhead_df$deadhead_mile, na.rm = TRUE) + sum(end_deadhead_df$deadhead_mile, na.rm = TRUE)

total_deadhead1 <- sum(route_timetable_df$deaddist_start, na.rm = TRUE) + sum(route_timetable_df$deaddist_end, na.rm = TRUE)+sum(route_timetable_df$deaddist_mid, na.rm = TRUE)

Rev_mile1 <- sum(route_timetable_df$distance, na.rm = TRUE)

source("OSM_Distance_function.R")
block_timetable_df2 <- block_timetable_df1 %>% 
  mutate(Sdistance=0.0,
         Sduration=0.0,
         Edistance=0.0,
         Eduration=0.0,
         Sdistance_A=0.0,
         Sduration_A=0.0,
         Edistance_A=0.0,
         Eduration_A=0.0, 
         Sdistance_B=0.0,
         Sduration_B=0.0,
         Edistance_B=0.0,
         Eduration_B=0.0, 
         Sdistance_C=0.0,
         Sduration_C=0.0,
         Edistance_C=0.0,
         Eduration_C=0.0
  )

for(i in 1:nrow(block_timetable_df2)){
  tempstr<-paste(block_timetable_df2$start_stop[i],block_timetable_df2$start_div[i])
  if(is.null(h1[[tempstr]])){
    skim<-distance2point3(c(block_timetable_df2$SLong[i],block_timetable_df2$SLat[i],block_timetable_df2$FTLong[i],block_timetable_df2$FTLat[i]))
    block_timetable_df2$Sdistance[i]=skim[1]  
    block_timetable_df2$Sduration[i]=skim[2]         
    h1[[tempstr]]<-skim
  }else{
    block_timetable_df2$Sdistance[i]=h1[[tempstr]][1]  
    block_timetable_df2$Sduration[i]=h1[[tempstr]][2]
  }

  tempstr<-paste(block_timetable_df2$end_stop[i],block_timetable_df2$start_div[i])
  if(is.null(h1[[tempstr]])){
    skim<-distance2point3(c(block_timetable_df2$ELong[i],block_timetable_df2$ELat[i],block_timetable_df2$FTLong[i],block_timetable_df2$FTLat[i]))
    block_timetable_df2$Edistance[i]=skim[1]  
    block_timetable_df2$Eduration[i]=skim[2]         
    h1[[tempstr]]<-skim
  }else{
    block_timetable_df2$Edistance[i]=h1[[tempstr]][1]  
    block_timetable_df2$Eduration[i]=h1[[tempstr]][2]
  }  
  
 for(j in 1:nrow(facility)){
    if(j==1){
    
      tempstr<-paste(block_timetable_df2$start_stop[i],facility$FT_Alias[j])
      if(is.null(h1[[tempstr]])){
        skim<-distance2point3(c(block_timetable_df2$SLong[i],block_timetable_df2$SLat[i],facility$FTLong[j],facility$FTLat[j]))
        block_timetable_df2$Sdistance_A[i]=skim[1]  
        block_timetable_df2$Sduration_A[i]=skim[2]         
        h1[[tempstr]]<-skim
      }else{
        block_timetable_df2$Sdistance_A[i]=h1[[tempstr]][1]  
        block_timetable_df2$Sduration_A[i]=h1[[tempstr]][2]
      }  
      

      tempstr<-paste(block_timetable_df2$end_stop[i],facility$FT_Alias[j])
      if(is.null(h1[[tempstr]])){
        skim<-distance2point3(c(block_timetable_df2$ELong[i],block_timetable_df2$ELat[i],facility$FTLong[j],facility$FTLat[j]))
        block_timetable_df2$Edistance_A[i]=skim[1]  
        block_timetable_df2$Eduration_A[i]=skim[2]         
        h1[[tempstr]]<-skim
      }else{
        block_timetable_df2$Edistance_A[i]=h1[[tempstr]][1]  
        block_timetable_df2$Eduration_A[i]=h1[[tempstr]][2]
      }        

    }
    
    if(j==2){
      
      
      tempstr<-paste(block_timetable_df2$start_stop[i],facility$FT_Alias[j])
      if(is.null(h1[[tempstr]])){
        skim<-distance2point3(c(block_timetable_df2$SLong[i],block_timetable_df2$SLat[i],facility$FTLong[j],facility$FTLat[j]))
        block_timetable_df2$Sdistance_B[i]=skim[1]  
        block_timetable_df2$Sduration_B[i]=skim[2]         
        h1[[tempstr]]<-skim
      }else{
        block_timetable_df2$Sdistance_B[i]=h1[[tempstr]][1]  
        block_timetable_df2$Sduration_B[i]=h1[[tempstr]][2]
      }  
      
      
      tempstr<-paste(block_timetable_df2$end_stop[i],facility$FT_Alias[j])
      if(is.null(h1[[tempstr]])){
        skim<-distance2point3(c(block_timetable_df2$ELong[i],block_timetable_df2$ELat[i],facility$FTLong[j],facility$FTLat[j]))
        block_timetable_df2$Edistance_B[i]=skim[1]  
        block_timetable_df2$Eduration_B[i]=skim[2]         
        h1[[tempstr]]<-skim
      }else{
        block_timetable_df2$Edistance_B[i]=h1[[tempstr]][1]  
        block_timetable_df2$Eduration_B[i]=h1[[tempstr]][2]
      }   
    }
    
    if(j==3){
      
      
      tempstr<-paste(block_timetable_df2$start_stop[i],facility$FT_Alias[j])
      if(is.null(h1[[tempstr]])){
        skim<-distance2point3(c(block_timetable_df2$SLong[i],block_timetable_df2$SLat[i],facility$FTLong[j],facility$FTLat[j]))
        block_timetable_df2$Sdistance_C[i]=skim[1]  
        block_timetable_df2$Sduration_C[i]=skim[2]         
        h1[[tempstr]]<-skim
      }else{
        block_timetable_df2$Sdistance_C[i]=h1[[tempstr]][1]  
        block_timetable_df2$Sduration_C[i]=h1[[tempstr]][2]
      }  
      
      
      tempstr<-paste(block_timetable_df2$end_stop[i],facility$FT_Alias[j])
      if(is.null(h1[[tempstr]])){
        skim<-distance2point3(c(block_timetable_df2$ELong[i],block_timetable_df2$ELat[i],facility$FTLong[j],facility$FTLat[j]))
        block_timetable_df2$Edistance_C[i]=skim[1]  
        block_timetable_df2$Eduration_C[i]=skim[2]         
        h1[[tempstr]]<-skim
      }else{
        block_timetable_df2$Edistance_C[i]=h1[[tempstr]][1]  
        block_timetable_df2$Eduration_C[i]=h1[[tempstr]][2]
      }  
    }
    
  }
}

block_timetable_df2$distance_A=block_timetable_df2$Sdistance_A+block_timetable_df2$Edistance_A
block_timetable_df2$distance_B=block_timetable_df2$Sdistance_B+block_timetable_df2$Edistance_B
block_timetable_df2$distance_C=block_timetable_df2$Sdistance_C+block_timetable_df2$Edistance_C

block_timetable_df2$duration_A=block_timetable_df2$Sduration_A+block_timetable_df2$Eduration_A
block_timetable_df2$duration_B=block_timetable_df2$Sduration_B+block_timetable_df2$Eduration_B
block_timetable_df2$duration_C=block_timetable_df2$Sduration_C+block_timetable_df2$Eduration_C

block_timetable_df2$Min_div=""
block_timetable_df2$Deaddistnew=0.0
block_timetable_df2$Deaddistfix=0.0
for(i in 1:nrow(block_timetable_df2)){
  if(block_timetable_df2$distance_A[i]<=block_timetable_df2$distance_B[i] & block_timetable_df2$distance_A[i]<=block_timetable_df2$distance_C[i]){
    block_timetable_df2$Min_div[i]="A"
    block_timetable_df2$Deaddistnew[i]=block_timetable_df2$distance_A[i]}
  if(block_timetable_df2$distance_B[i]<=block_timetable_df2$distance_A[i] & block_timetable_df2$distance_B[i]<=block_timetable_df2$distance_C[i]){
    block_timetable_df2$Min_div[i]="B"
    block_timetable_df2$Deaddistnew[i]=block_timetable_df2$distance_B[i]}
  if(block_timetable_df2$distance_C[i]<=block_timetable_df2$distance_A[i] & block_timetable_df2$distance_C[i]<=block_timetable_df2$distance_B[i]){
    block_timetable_df2$Min_div[i]="C"
    block_timetable_df2$Deaddistnew[i]=block_timetable_df2$distance_C[i]}
  if(block_timetable_df2$start_div[i]=="A"){block_timetable_df2$Deaddistfix[i]<-block_timetable_df2$distance_A[i]}
  if(block_timetable_df2$start_div[i]=="B"){block_timetable_df2$Deaddistfix[i]<-block_timetable_df2$distance_B[i]}
  if(block_timetable_df2$start_div[i]=="C"){block_timetable_df2$Deaddistfix[i]<-block_timetable_df2$distance_C[i]}
}  

#block_timetable_df2 = subset(block_timetable_df2, select = -c(Deadheadnew,Deadheadfix) )

write.csv(block_timetable_df2, "data/ALL_deadhead_dist_5.csv", row.names = FALSE)
