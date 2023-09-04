library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(foreign)
library("rjson")
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

#s2s_infor<- read.csv("data/s2s_coor_OSM.csv") 
s2s_midinfor<- s2s_midpair
s2s_midinfor1 <- s2s_midinfor %>% 
  mutate(distance=0.0,
         duration=0.0)

for(i in 1:nrow(s2s_midinfor)){
#for(i in 1){
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",s2s_midinfor1$FLong[i],',',s2s_midinfor1$FLat[i],';',s2s_midinfor1$TLong[i],',',s2s_midinfor1$TLat[i],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  s2s_midinfor1$distance[i]=json_data$routes[[1]]$distance/1000/1.60934   # meters
  s2s_midinfor1$duration[i]=json_data$routes[[1]]$duration/3600   # seconds
}

write.csv(s2s_midinfor1, "data/Mid_deadhead_dist_2.csv", row.names = FALSE)



s2s_infor<- block_timetable_df1
s2s_infor1 <- s2s_infor %>% 
  mutate(Sdistance=0.0,
         Sduration=0.0,
         Edistance=0.0,
         Eduration=0.0         
         )

for(i in 1:nrow(s2s_infor)){
  #for(i in 1){
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",s2s_infor$SLong[i],',',s2s_infor$SLat[i],';',s2s_infor$FTLong[i],',',s2s_infor$FTLat[i],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  s2s_infor1$Sdistance[i]=json_data$routes[[1]]$distance/1000/1.60934   # meters
  s2s_infor1$Sduration[i]=json_data$routes[[1]]$duration/3600   # seconds
  
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",s2s_infor$ELong[i],',',s2s_infor$ELat[i],';',s2s_infor$FTLong[i],',',s2s_infor$FTLat[i],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  s2s_infor1$Edistance[i]=json_data$routes[[1]]$distance/1000/1.60934  # meters
  s2s_infor1$Eduration[i]=json_data$routes[[1]]$duration/3600   # seconds
}

write.csv(s2s_infor1, "data/Mid_deadhead_dist_3.csv", row.names = FALSE)


## the following for the calculating the shortest distance between block and each facility
s2s_infor<- block_timetable_df1
s2s_infor1 <- s2s_infor %>% 
  mutate(Sdistance_A=0.0,
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

for(i in 1:nrow(s2s_infor)){
  for(j in 1:nrow(facility)){
  if(j==1){
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",s2s_infor$SLong[i],',',s2s_infor$SLat[i],';',facility$FTLong[j],',',facility$FTLat[j],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  s2s_infor1$Sdistance_A[i]=json_data$routes[[1]]$distance/1000/1.60934   # meters
  s2s_infor1$Sduration_A[i]=json_data$routes[[1]]$duration/3600   # seconds
  
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",s2s_infor$ELong[i],',',s2s_infor$ELat[i],';',facility$FTLong[j],',',facility$FTLat[j],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  s2s_infor1$Edistance_A[i]=json_data$routes[[1]]$distance/1000/1.60934  # meters
  s2s_infor1$Eduration_A[i]=json_data$routes[[1]]$duration/3600   # seconds
  }
    
  if(j==2){
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",s2s_infor$SLong[i],',',s2s_infor$SLat[i],';',facility$FTLong[j],',',facility$FTLat[j],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  s2s_infor1$Sdistance_B[i]=json_data$routes[[1]]$distance/1000/1.60934   # meters
  s2s_infor1$Sduration_B[i]=json_data$routes[[1]]$duration/3600   # seconds
    
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",s2s_infor$ELong[i],',',s2s_infor$ELat[i],';',facility$FTLong[j],',',facility$FTLat[j],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  s2s_infor1$Edistance_B[i]=json_data$routes[[1]]$distance/1000/1.60934  # meters
  s2s_infor1$Eduration_B[i]=json_data$routes[[1]]$duration/3600   # seconds
  }
    
  if(j==3){
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",s2s_infor$SLong[i],',',s2s_infor$SLat[i],';',facility$FTLong[j],',',facility$FTLat[j],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  s2s_infor1$Sdistance_C[i]=json_data$routes[[1]]$distance/1000/1.60934   # meters
  s2s_infor1$Sduration_C[i]=json_data$routes[[1]]$duration/3600   # seconds
      
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",s2s_infor$ELong[i],',',s2s_infor$ELat[i],';',facility$FTLong[j],',',facility$FTLat[j],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  s2s_infor1$Edistance_C[i]=json_data$routes[[1]]$distance/1000/1.60934  # meters
  s2s_infor1$Eduration_C[i]=json_data$routes[[1]]$duration/3600   # seconds
    }
    
  }
}

s2s_infor1$distance_A=s2s_infor1$Sdistance_A+s2s_infor1$Edistance_A
s2s_infor1$distance_B=s2s_infor1$Sdistance_B+s2s_infor1$Edistance_B
s2s_infor1$distance_C=s2s_infor1$Sdistance_C+s2s_infor1$Edistance_C

s2s_infor1$duration_A=s2s_infor1$Sduration_A+s2s_infor1$Eduration_A
s2s_infor1$duration_B=s2s_infor1$Sduration_B+s2s_infor1$Eduration_B
s2s_infor1$duration_C=s2s_infor1$Sduration_C+s2s_infor1$Eduration_C

s2s_infor1$Min_div=""
s2s_infor1$Deaddistnew=0.0
s2s_infor1$Deaddistfix=0.0
for(i in 1:nrow(s2s_infor1)){
  if(s2s_infor1$distance_A[i]<=s2s_infor1$distance_B[i] & s2s_infor1$distance_A[i]<=s2s_infor1$distance_C[i]){
    s2s_infor1$Min_div[i]="A"
    s2s_infor1$Deaddistnew[i]=s2s_infor1$distance_A[i]}
  if(s2s_infor1$distance_B[i]<=s2s_infor1$distance_A[i] & s2s_infor1$distance_B[i]<=s2s_infor1$distance_C[i]){
    s2s_infor1$Min_div[i]="B"
    s2s_infor1$Deaddistnew[i]=s2s_infor1$distance_B[i]}
  if(s2s_infor1$distance_C[i]<=s2s_infor1$distance_A[i] & s2s_infor1$distance_C[i]<=s2s_infor1$distance_B[i]){
    s2s_infor1$Min_div[i]="C"
    s2s_infor1$Deaddistnew[i]=s2s_infor1$distance_C[i]}
  if(s2s_infor1$start_div[i]=="A"){s2s_infor1$Deaddistfix[i]=s2s_infor1$distance_A[i]}
  if(s2s_infor1$start_div[i]=="B"){s2s_infor1$Deaddistfix[i]=s2s_infor1$distance_B[i]}
  if(s2s_infor1$start_div[i]=="C"){s2s_infor1$Deaddistfix[i]=s2s_infor1$distance_C[i]}
  
}

s2s_infor1 = subset(s2s_infor1, select = -c(Deadheadnew,Deadheadfix) )

write.csv(s2s_infor1, "data/ALL_deadhead_dist_4.csv", row.names = FALSE)