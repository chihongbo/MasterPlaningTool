library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(foreign)
library("rjson")
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
distance2point<-function(pointdata){
  stopAselection<-stops%>%filter(stop_id == pointdata[[1]])
  stopBselection<-stops%>%filter(stop_id == pointdata[[2]])
  
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",stopAselection$stop_lon[1],',',stopAselection$stop_lat[1],';',stopBselection$stop_lon[1],',',stopBselection$stop_lat[1],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  distance=json_data$routes[[1]]$distance/1000/1.60934   # distance
  duration=json_data$routes[[1]]$duration/3600   # hour
  skim<-c(distance,duration)
}


distance2point2<-function(pointdata){
  stopAselection<-stops%>%filter(stop_id == pointdata[[1]])
  stopBselection<-facility%>%filter(FT_Alias == pointdata[[2]])
  
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",stopAselection$stop_lon[1],',',stopAselection$stop_lat[1],';',stopBselection$FTLong[1],',',stopBselection$FTLat[1],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  distance=json_data$routes[[1]]$distance/1000/1.60934   # distance
  duration=json_data$routes[[1]]$duration/3600   # hour
  skim<-c(distance,duration)
}


distance2point3<-function(pointdata){
  url=gsub(" ", "",paste("http://127.0.0.1:5000/route/v1/driving/",pointdata[1],',',pointdata[2],';',pointdata[3],',',pointdata[4],'?annotations=distance'))
  json_file <- url
  json_data <- fromJSON(paste(readLines(json_file), collapse=""))
  distance=json_data$routes[[1]]$distance/1000/1.60934   # distance
  duration=json_data$routes[[1]]$duration/3600   # hour
  skim<-c(distance,duration)
}


