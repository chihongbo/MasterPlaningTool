suppressMessages(library(dplyr))
suppressMessages(library(tidyr))
suppressMessages(library(ggplot2))
suppressMessages(library(stringr))

summarize_route <- function(scenario) {
	data <- read.csv(paste0('inputs/', scenario, '/route.csv'))
	data <- data %>% 
				filter(!(route_type %in% c("LR", "HR"))) %>%
				mutate(route_type = str_replace(route_type, "L", "Local"),
					   route_type = str_replace(route_type, "E", "Express")) %>%
				group_by(route_type) %>%
				summarize(route = n(), veh = sum(veh))
	return(data)
}

route_base <- summarize_route('base') %>% mutate(scenario = 'base')
route_s1 <- summarize_route('scenario_1') %>% mutate(scenario = 'scenario 1')
route_s2 <- summarize_route('scenario_2') %>% mutate(scenario = 'scenario 2')
route_s3 <- summarize_route('scenario_3') %>% mutate(scenario = 'scenario 3')
route_s4 <- summarize_route('scenario_4') %>% mutate(scenario = 'scenario 4')
print(route_base)
print(route_s1)
print(route_s2)
print(route_s3)
print(route_s4)

# route_all <- bind_rows(route_base, route_s1, route_s2, route_s3, route_s4)
# print(route_all)
# ggplot(route_all, aes(x = scenario, y = route, fill = route_type)) +
# 	geom_col(position = "dodge", stat='identity') +
# 	labs(x = 'Scenario', y = 'Number of routes', fill = 'Route Type') + 
# 	geom_text(aes(label=route), position=position_dodge(width=0.9), vjust=-0.25) +
# 	theme_light()