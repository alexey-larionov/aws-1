# ggplot_heatmap.r
# Plotting heatmap for fastqc summary
# Alexey Larionov, 16Feb2017

# Use: 
# ggplot_heatmap.r data_file plot_title plot_file

# Note: requires ggplot 2.2.1 +

# Read parameters
args <- commandArgs(trailingOnly=TRUE)
data_file <- args[1]
plot_title <- args[2]
plot_file <- args[3]

# Load libraries
library(ggplot2)
library(reshape2)
library(dplyr)

# Data for plot
x <-read.table(data_file, header = TRUE)
"sample" -> colnames(x)[1]
y <- melt(x, id.vars="sample")

# Colours for plot
colours <- c("PASS" = "green", "WARN" = "yellow", "FAIL" = "red")

# Make plot
g <- ggplot(y, aes(variable, sample)) +
  geom_tile(aes(fill = value), colour = "black") +
  scale_fill_manual(values=colours) + 
  labs(x = "", y = "") + 
  theme(axis.text.y = element_text(face="bold", size=14)) +
  theme(axis.text.x = element_text(hjust=0, size=12, angle=45)) + 
  scale_x_discrete(position = "top") +
  ggtitle(plot_title) + 
  theme(plot.title = element_text(size=18, hjust = 0.5, face="bold"))

# Save plot
ggsave(file=plot_file)

