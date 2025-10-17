# Pitcher Arsenal Clustering - Setup Script
# Install and load all required packages

print("Starting package installation...")

# Install required packages
install.packages("baseballr")
install.packages("tidyverse")
install.packages("cluster")
install.packages("factoextra")

print("Packages installed. Loading libraries...")

# Load libraries
library(baseballr)
library(tidyverse)
library(cluster)
library(factoextra)

print("All packages loaded successfully!")