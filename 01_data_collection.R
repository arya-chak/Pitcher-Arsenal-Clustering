# Pitcher Arsenal Clustering - Data Collection
# Downloads Statcast data from Baseball Savant

library(tidyverse)

# Define date range for data collection
start_date <- "2024-04-01"
end_date <- "2024-04-30"

print(paste("Downloading Statcast data from", start_date, "to", end_date))

# Construct Baseball Savant URL
url <- sprintf("https://baseballsavant.mlb.com/statcast_search/csv?all=true&hfPT=&hfAB=&hfGT=R%%7C&hfPR=&hfZ=&stadium=&hfBBL=&hfNewZones=&hfPull=&hfC=&hfSea=2024%%7C&hfSit=&player_type=pitcher&hfOuts=&opponent=&pitcher_throws=&batter_stands=&hfSA=&game_date_gt=%s&game_date_lt=%s&hfMo=&hfTeam=&home_road=&hfRO=&position=&hfInfield=&hfOutfield=&hfInn=&hfBBT=&hfFlag=&metric_1=&group_by=name&min_pitches=0&min_results=0&min_pas=0&sort_col=pitches&player_event_sort=api_p_release_speed&sort_order=desc&type=details&", 
               start_date, end_date)

# Download the data
statcast_data <- read_csv(url, show_col_types = FALSE)

# Verify data loaded successfully
print(paste("✓ Total pitches loaded:", nrow(statcast_data)))
print(paste("✓ Unique pitchers:", n_distinct(statcast_data$pitcher)))

print("\nPitch type distribution:")
statcast_data %>% 
  count(pitch_type, sort = TRUE) %>%
  print()