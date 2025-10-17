# Pitcher Arsenal Clustering - Analysis & Clustering
# Aggregates pitcher data and performs k-means clustering

library(tidyverse)
library(cluster)
library(factoextra)

print("Starting pitcher aggregation and clustering analysis...")

# ===== 1. DATA CLEANING =====

statcast_clean <- statcast_data %>%
  filter(!is.na(release_spin_rate),
         !is.na(pitch_type),
         !is.na(release_speed))

print(paste("✓ Pitches after cleaning:", nrow(statcast_clean)))

# ===== 2. AGGREGATE PITCHER PROFILES =====

# Calculate stats per pitcher per pitch type
pitcher_profiles <- statcast_clean %>%
  group_by(pitcher, player_name, pitch_type) %>%
  summarise(
    n_pitches = n(),
    avg_speed = mean(release_speed, na.rm = TRUE),
    avg_spin = mean(release_spin_rate, na.rm = TRUE),
    avg_pfx_x = mean(pfx_x, na.rm = TRUE),
    avg_pfx_z = mean(pfx_z, na.rm = TRUE),
    .groups = "drop"
  )

# Calculate total pitches per pitcher
pitcher_totals <- statcast_clean %>%
  group_by(pitcher, player_name) %>%
  summarise(total_pitches = n(), .groups = "drop")

# Calculate pitch percentages and filter to qualified pitchers
pitcher_profiles <- pitcher_profiles %>%
  left_join(pitcher_totals, by = c("pitcher", "player_name")) %>%
  mutate(pitch_pct = n_pitches / total_pitches * 100) %>%
  filter(total_pitches >= 50)

print(paste("✓ Qualified pitchers (50+ pitches):", n_distinct(pitcher_profiles$pitcher)))

# ===== 3. CREATE WIDE-FORMAT CLUSTERING DATA =====

clustering_data <- pitcher_profiles %>%
  select(pitcher, player_name, pitch_type, pitch_pct, avg_speed, 
         avg_spin, avg_pfx_x, avg_pfx_z) %>%
  pivot_wider(
    names_from = pitch_type,
    values_from = c(pitch_pct, avg_speed, avg_spin, avg_pfx_x, avg_pfx_z),
    values_fill = 0
  )

# ===== 4. PREPARE FOR CLUSTERING =====

# Save pitcher names for later
pitcher_names <- clustering_data %>%
  select(pitcher, player_name)

# Extract and scale numeric features
clustering_features <- clustering_data %>%
  select(-pitcher, -player_name)

clustering_features[is.na(clustering_features)] <- 0
clustering_features_scaled <- scale(clustering_features)

print(paste("✓ Features for clustering:", ncol(clustering_features)))

# ===== 5. DETERMINE OPTIMAL K =====

set.seed(123)

print("Computing elbow method and silhouette scores...")

# Elbow method
wss <- sapply(2:10, function(k) {
  kmeans(clustering_features_scaled, centers = k, nstart = 25)$tot.withinss
})

elbow_data <- data.frame(k = 2:10, wss = wss)

elbow_plot <- ggplot(elbow_data, aes(x = k, y = wss)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  labs(title = "Elbow Method for Optimal k",
       x = "Number of Clusters (k)",
       y = "Within-Cluster Sum of Squares") +
  theme_minimal() +
  scale_x_continuous(breaks = 2:10)

# Silhouette analysis
sil_scores <- sapply(2:10, function(k) {
  km <- kmeans(clustering_features_scaled, centers = k, nstart = 25)
  ss <- silhouette(km$cluster, dist(clustering_features_scaled))
  mean(ss[, 3])
})

sil_data <- data.frame(k = 2:10, silhouette = sil_scores)

sil_plot <- ggplot(sil_data, aes(x = k, y = silhouette)) +
  geom_line(linewidth = 1) +
  geom_point(size = 3) +
  labs(title = "Silhouette Analysis",
       x = "Number of Clusters (k)",
       y = "Average Silhouette Width") +
  theme_minimal() +
  scale_x_continuous(breaks = 2:10)

# ===== 6. RUN K-MEANS CLUSTERING =====

k <- 4
set.seed(123)

print(paste("Running k-means clustering with k =", k))

kmeans_result <- kmeans(clustering_features_scaled, 
                        centers = k, 
                        nstart = 25,
                        iter.max = 100)

# ===== 7. ASSIGN CLUSTER LABELS =====

pitcher_names$cluster <- kmeans_result$cluster

clustering_results <- clustering_data %>%
  left_join(pitcher_names %>% select(pitcher, cluster), by = "pitcher") %>%
  mutate(cluster_name = case_when(
    cluster == 1 ~ "Sinker-Slider Specialists",
    cluster == 2 ~ "Unique Arsenal (Outlier)",
    cluster == 3 ~ "Power Fastball Pitchers",
    cluster == 4 ~ "Balanced Arsenal"
  ))

# ===== 8. VISUALIZE CLUSTERS WITH PCA =====

pca_result <- prcomp(clustering_features_scaled)

pca_data <- data.frame(
  PC1 = pca_result$x[, 1],
  PC2 = pca_result$x[, 2],
  cluster_name = clustering_results$cluster_name,
  player_name = clustering_results$player_name
)

cluster_plot <- ggplot(pca_data, aes(x = PC1, y = PC2, color = cluster_name)) +
  geom_point(size = 3, alpha = 0.6) +
  labs(title = "Pitcher Arsenal Clusters",
       subtitle = "Projected onto first 2 Principal Components",
       x = paste0("PC1 (", round(summary(pca_result)$importance[2,1]*100, 1), "% variance)"),
       y = paste0("PC2 (", round(summary(pca_result)$importance[2,2]*100, 1), "% variance)"),
       color = "Cluster") +
  theme_minimal() +
  theme(legend.position = "bottom")

# ===== 9. SAVE RESULTS =====

print("\nSaving results...")

write_csv(clustering_results, "pitcher_clusters.csv")
ggsave("cluster_plot.png", plot = cluster_plot, width = 10, height = 8, dpi = 300)
ggsave("elbow_plot.png", plot = elbow_plot, width = 8, height = 6, dpi = 300)
ggsave("silhouette_plot.png", plot = sil_plot, width = 8, height = 6, dpi = 300)

print("✓ Results saved to pitcher_clusters.csv")
print("✓ Plots saved: cluster_plot.png, elbow_plot.png, silhouette_plot.png")

# ===== 10. DISPLAY SUMMARY & PLOTS =====

print("\n========================================")
print("       PROJECT SUMMARY")
print("========================================")
print(paste("Total pitchers analyzed:", nrow(clustering_results)))
print(paste("Total pitches analyzed:", nrow(statcast_clean)))
print(paste("Number of features:", ncol(clustering_features)))
print(paste("Optimal k clusters:", k))

print("\n--- Cluster Distribution ---")
print(table(clustering_results$cluster_name))

print("\nDisplaying plots...")
print(cluster_plot)
print(elbow_plot)
print(sil_plot)

print("\n✓ Analysis complete!")