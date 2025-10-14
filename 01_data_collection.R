# Load libraries
library(tidyverse)

# Try a broader date range - full month of April 2024
start_date <- "2024-04-01"
end_date <- "2024-04-30"

print(paste("Attempting to download data from", start_date, "to", end_date))

# Simpler URL construction
url <- sprintf("https://baseballsavant.mlb.com/statcast_search/csv?all=true&hfPT=&hfAB=&hfGT=R%%7C&hfPR=&hfZ=&stadium=&hfBBL=&hfNewZones=&hfPull=&hfC=&hfSea=2024%%7C&hfSit=&player_type=pitcher&hfOuts=&opponent=&pitcher_throws=&batter_stands=&hfSA=&game_date_gt=%s&game_date_lt=%s&hfMo=&hfTeam=&home_road=&hfRO=&position=&hfInfield=&hfOutfield=&hfInn=&hfBBT=&hfFlag=&metric_1=&group_by=name&min_pitches=0&min_results=0&min_pas=0&sort_col=pitches&player_event_sort=api_p_release_speed&sort_order=desc&type=details&", 
               start_date, end_date)

# Download the data
statcast_data <- read_csv(url, show_col_types = FALSE)

# Check results
print(paste("Total pitches:", nrow(statcast_data)))

# If we got data, show a sample
if(nrow(statcast_data) > 0) {
  print("Success! Here's a sample:")
  print(statcast_data %>% 
    select(player_name, pitch_type, release_speed, game_date) %>% 
    head(10))
} else {
  print("Still no data. Let's try a different approach...")
}

# Explore the data structure
print("Data dimensions:")
dim(statcast_data)

print("\nKey columns for our analysis:")
statcast_data %>% 
  select(player_name, pitcher, pitch_type, release_speed, 
         pfx_x, pfx_z, release_pos_x, release_pos_z,
         spin_rate, effective_speed) %>% 
  head(5)

# Check how many unique pitchers we have
print(paste("\nUnique pitchers:", n_distinct(statcast_data$pitcher)))

# Check pitch type distribution
print("\nPitch types in the data:")
statcast_data %>% 
  count(pitch_type, sort = TRUE)

# Check for missing values in key columns
print("\nMissing values in key columns:")
statcast_data %>% 
  select(pitch_type, release_speed, pfx_x, pfx_z, spin_rate) %>% 
  summarise(across(everything(), ~sum(is.na(.))))

# Let's see all column names to find the right ones
print("All column names:")
names(statcast_data)

# Explore key columns for our analysis
print("Key columns for clustering:")
statcast_data %>% 
  select(player_name, pitcher, pitch_type, release_speed, 
         pfx_x, pfx_z, release_pos_x, release_pos_z,
         release_spin_rate, release_extension, pitch_name) %>% 
  head(10)

# Check for missing values in key columns
print("\nMissing values in key columns:")
statcast_data %>% 
  select(pitch_type, release_speed, pfx_x, pfx_z, release_spin_rate) %>% 
  summarise(across(everything(), ~sum(is.na(.))))

# Get summary statistics for key numeric variables
print("\nSummary of key variables:")
statcast_data %>% 
  select(release_speed, pfx_x, pfx_z, release_spin_rate) %>% 
  summary()