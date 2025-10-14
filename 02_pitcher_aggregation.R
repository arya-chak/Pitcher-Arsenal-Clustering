# Load libraries and data
library(tidyverse)

# Assuming statcast_data is already loaded
# If not, you'll need to reload it from the previous step

# Remove pitches with missing key values
statcast_clean <- statcast_data %>%
  filter(!is.na(release_spin_rate),
         !is.na(pitch_type),
         !is.na(release_speed))

print(paste("Pitches after cleaning:", nrow(statcast_clean)))

# Calculate pitch mix percentages and average characteristics per pitcher
pitcher_profiles <- statcast_clean %>%
  group_by(pitcher, player_name, pitch_type) %>%
  summarise(
    n_pitches = n(),
    avg_speed = mean(release_speed, na.rm = TRUE),
    avg_spin = mean(release_spin_rate, na.rm = TRUE),
    avg_pfx_x = mean(pfx_x, na.rm = TRUE),  # horizontal movement
    avg_pfx_z = mean(pfx_z, na.rm = TRUE),  # vertical movement
    .groups = "drop"
  )

# Get total pitches per pitcher
pitcher_totals <- statcast_clean %>%
  group_by(pitcher, player_name) %>%
  summarise(total_pitches = n(), .groups = "drop")

# Calculate pitch mix percentages
pitcher_profiles <- pitcher_profiles %>%
  left_join(pitcher_totals, by = c("pitcher", "player_name")) %>%
  mutate(pitch_pct = n_pitches / total_pitches * 100)

# View the results
print("Sample of pitcher profiles:")
pitcher_profiles %>%
  arrange(pitcher, desc(pitch_pct)) %>%
  head(20)

# Filter to pitchers with at least 50 pitches (to avoid small samples)
pitcher_profiles_filtered <- pitcher_profiles %>%
  filter(total_pitches >= 50)

print(paste("\nPitchers with 50+ pitches:", 
            n_distinct(pitcher_profiles_filtered$pitcher)))

# Create a wide-format dataset for clustering
# We'll create features for the most common pitch types

# First, let's see which pitch types are most common
print("Pitch type frequencies:")
pitcher_profiles_filtered %>%
  count(pitch_type, sort = TRUE)

# Create features for clustering
# For each pitcher, we'll pivot the data to have columns like:
# FF_pct, FF_speed, FF_spin, SL_pct, SL_speed, etc.

clustering_data <- pitcher_profiles_filtered %>%
  select(pitcher, player_name, pitch_type, pitch_pct, avg_speed, 
         avg_spin, avg_pfx_x, avg_pfx_z) %>%
  pivot_wider(
    names_from = pitch_type,
    values_from = c(pitch_pct, avg_speed, avg_spin, avg_pfx_x, avg_pfx_z),
    values_fill = 0
  )

# View the structure
print("\nClustering dataset dimensions:")
dim(clustering_data)

print("\nFirst few columns:")
names(clustering_data)[1:20]

print("\nSample of clustering data:")
clustering_data %>%
  select(1:10) %>%
  head(5)

# Check how many columns we have
print(paste("\nTotal features:", ncol(clustering_data) - 2))  # minus pitcher and player_name

# Prepare data for clustering
# Save pitcher names for later reference
pitcher_names <- clustering_data %>%
  select(pitcher, player_name)

# Select only numeric features for clustering
clustering_features <- clustering_data %>%
  select(-pitcher, -player_name)

# Check for any NA values
print("Missing values per column:")
colSums(is.na(clustering_features))

# Replace any remaining NAs with 0 (these would be pitch types not thrown)
clustering_features[is.na(clustering_features)] <- 0

# Standardize the features (mean = 0, sd = 1)
# This is CRITICAL for k-means clustering
clustering_features_scaled <- scale(clustering_features)

print("\nScaled data dimensions:")
dim(clustering_features_scaled)

print("\nFirst pitcher's scaled features (first 10):")
clustering_features_scaled[1, 1:10]

print("\nData is ready for clustering!")

# Load clustering libraries
library(cluster)
library(factoextra)

# Set seed for reproducibility
set.seed(123)

# Determine optimal number of clusters using elbow method
print("Computing elbow method (this may take a minute)...")

# Test k from 2 to 10
wss <- sapply(2:10, function(k) {
  kmeans(clustering_features_scaled, centers = k, nstart = 25)$tot.withinss
})

# Create elbow plot
elbow_data <- data.frame(k = 2:10, wss = wss)

print("\nWithin-cluster sum of squares by k:")
print(elbow_data)

# Plot the elbow curve
elbow_plot <- ggplot(elbow_data, aes(x = k, y = wss)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  labs(title = "Elbow Method for Optimal k",
       x = "Number of Clusters (k)",
       y = "Within-Cluster Sum of Squares") +
  theme_minimal() +
  scale_x_continuous(breaks = 2:10)

print(elbow_plot)

# Calculate silhouette scores
print("\nComputing silhouette scores...")

sil_scores <- sapply(2:10, function(k) {
  km <- kmeans(clustering_features_scaled, centers = k, nstart = 25)
  ss <- silhouette(km$cluster, dist(clustering_features_scaled))
  mean(ss[, 3])
})

sil_data <- data.frame(k = 2:10, silhouette = sil_scores)

print("\nAverage silhouette width by k:")
print(sil_data)

# Plot silhouette scores
sil_plot <- ggplot(sil_data, aes(x = k, y = silhouette)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  labs(title = "Silhouette Analysis",
       x = "Number of Clusters (k)",
       y = "Average Silhouette Width") +
  theme_minimal() +
  scale_x_continuous(breaks = 2:10)

print(sil_plot)

# Run k-means with k=4
set.seed(123)
k <- 4

print(paste("Running k-means with k =", k))

kmeans_result <- kmeans(clustering_features_scaled, 
                        centers = k, 
                        nstart = 25,
                        iter.max = 100)

# Add cluster assignments to our data
pitcher_names$cluster <- kmeans_result$cluster

# Merge with original clustering data
clustering_results <- clustering_data %>%
  left_join(pitcher_names %>% select(pitcher, cluster), by = "pitcher")

# View cluster sizes
print("\nCluster sizes:")
table(clustering_results$cluster)

# Look at some example pitchers in each cluster
print("\nSample pitchers from each cluster:")
for(i in 1:k) {
  cat("\n--- Cluster", i, "---\n")
  print(clustering_results %>% 
    filter(cluster == i) %>% 
    select(player_name) %>% 
    head(10))
}

# Calculate cluster profiles
cluster_profiles <- clustering_results %>%
  group_by(cluster) %>%
  summarise(
    n_pitchers = n(),
    # Pitch mix percentages
    avg_FF_pct = mean(pitch_pct_FF),
    avg_SI_pct = mean(pitch_pct_SI),
    avg_SL_pct = mean(pitch_pct_SL),
    avg_CH_pct = mean(pitch_pct_CH),
    avg_CU_pct = mean(pitch_pct_CU),
    avg_FC_pct = mean(pitch_pct_FC),
    avg_ST_pct = mean(pitch_pct_ST),
    # Average velocities
    avg_FF_speed = mean(avg_speed_FF[avg_speed_FF > 0], na.rm = TRUE),
    avg_SI_speed = mean(avg_speed_SI[avg_speed_SI > 0], na.rm = TRUE),
    avg_SL_speed = mean(avg_speed_SL[avg_speed_SL > 0], na.rm = TRUE),
    avg_CH_speed = mean(avg_speed_CH[avg_speed_CH > 0], na.rm = TRUE),
    # Average spin rates
    avg_FF_spin = mean(avg_spin_FF[avg_spin_FF > 0], na.rm = TRUE),
    .groups = "drop"
  )

print("Cluster Profiles:")
print(cluster_profiles)

# Look at pitch mix in more detail
print("\nPitch Mix by Cluster:")
cluster_profiles %>%
  select(cluster, n_pitchers, avg_FF_pct, avg_SI_pct, avg_SL_pct, 
         avg_CH_pct, avg_CU_pct, avg_FC_pct)

# Look at velocities
print("\nAverage Velocities by Cluster:")
cluster_profiles %>%
  select(cluster, avg_FF_speed, avg_SI_speed, avg_SL_speed, avg_CH_speed)

# Create cluster labels
clustering_results <- clustering_results %>%
  mutate(cluster_name = case_when(
    cluster == 1 ~ "Sinker-Slider Specialists",
    cluster == 2 ~ "Unique Arsenal (Outlier)",
    cluster == 3 ~ "Power Fastball Pitchers",
    cluster == 4 ~ "Balanced Arsenal"
  ))

# Summary table
print("\nFINAL CLUSTER CLASSIFICATION:")
clustering_results %>%
  count(cluster, cluster_name) %>%
  arrange(cluster)

# Show notable pitchers in each main cluster
print("\n=== CLUSTER 1: Sinker-Slider Specialists (21 pitchers) ===")
clustering_results %>% 
  filter(cluster == 1) %>%
  select(player_name, pitch_pct_SI, pitch_pct_SL, pitch_pct_FF) %>%
  arrange(desc(pitch_pct_SI)) %>%
  head(10)

print("\n=== CLUSTER 3: Power Fastball Pitchers (53 pitchers) ===")
clustering_results %>% 
  filter(cluster == 3) %>%
  select(player_name, pitch_pct_FF, avg_speed_FF) %>%
  filter(avg_speed_FF > 0) %>%
  arrange(desc(avg_speed_FF)) %>%
  head(10)

print("\n=== CLUSTER 4: Balanced Arsenal (126 pitchers) ===")
clustering_results %>% 
  filter(cluster == 4) %>%
  select(player_name, pitch_pct_FF, pitch_pct_SL, pitch_pct_CH, pitch_pct_CU) %>%
  head(10)

# Create a final visualization - PCA plot of clusters
library(factoextra)

# Perform PCA for visualization
pca_result <- prcomp(clustering_features_scaled)

# Create a data frame for plotting
pca_data <- data.frame(
  PC1 = pca_result$x[, 1],
  PC2 = pca_result$x[, 2],
  cluster = as.factor(clustering_results$cluster),
  cluster_name = clustering_results$cluster_name,
  player_name = clustering_results$player_name
)

# Plot clusters in PCA space
cluster_plot <- ggplot(pca_data, aes(x = PC1, y = PC2, color = cluster_name)) +
  geom_point(size = 3, alpha = 0.6) +
  labs(title = "Pitcher Arsenal Clusters",
       subtitle = "Projected onto first 2 Principal Components",
       x = paste0("PC1 (", round(summary(pca_result)$importance[2,1]*100, 1), "% variance)"),
       y = paste0("PC2 (", round(summary(pca_result)$importance[2,2]*100, 1), "% variance)"),
       color = "Cluster") +
  theme_minimal() +
  theme(legend.position = "bottom")

print(cluster_plot)

# Save the final results
print("\n=== PROJECT SUMMARY ===")
print(paste("Total pitchers analyzed:", nrow(clustering_results)))
print(paste("Total pitches analyzed:", nrow(statcast_clean)))
print(paste("Number of features used:", ncol(clustering_features)))
print(paste("Optimal k clusters:", k))

print("\n=== CLUSTER SIZES ===")
table(clustering_results$cluster_name)

# Export results to CSV (optional)
write_csv(clustering_results, "pitcher_clusters.csv")
print("\nResults saved to 'pitcher_clusters.csv'")

# Save all three plots
ggsave("cluster_plot.png", plot = cluster_plot, width = 10, height = 8, dpi = 300)
ggsave("elbow_plot.png", plot = elbow_plot, width = 8, height = 6, dpi = 300)
ggsave("silhouette_plot.png", plot = sil_plot, width = 8, height = 6, dpi = 300)