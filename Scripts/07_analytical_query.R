# Load required libraries
library(tidyverse)
library(DBI)
library(RSQLite)

# ==============================================================================
# 1. CONNECT AND QUERY THE DATABASE
# ==============================================================================
# Connect to the FAIR-compliant SQLite database
db_path <- "C:/Users/jgspe/Documents/Brazil_ENSO_Sugarcane/Sugarcane_ENSO.db"
conn <- dbConnect(RSQLite::SQLite(), db_path)

# Pull the data, renaming SQL columns to match the required format for plotting
query <- "
  SELECT 
    Y.Region,
    Y.Year AS YEAR, 
    Y.Harvest_Month AS 'harv.month', 
    E.Phase AS classification, 
    Y.TCH_t_ha, 
    Y.Sugar_Yield_kg_tc, 
    Y.TSH_t_ha
  FROM Yield_Results Y
  JOIN ENSO_Lookup E ON Y.Year = E.Year
"

plantgro_wide <- dbGetQuery(conn, query)
dbDisconnect(conn) # Close the database connection

# ==============================================================================
# 2. PIVOT TO LONG FORMAT
# ==============================================================================
plantgro.harv_ALL <- plantgro_wide %>%
  pivot_longer(
    cols = c(TCH_t_ha, Sugar_Yield_kg_tc, TSH_t_ha), 
    names_to = "Variable", 
    values_to = "Value"
  ) %>%
  filter(!is.na(classification))

# ==============================================================================
# 3. INTERACTIVE SELECTION & PLOTS
# ==============================================================================

# --- A. INTERACTIVE REGION MENU ---
# Display English names in the menu, but map to the database keys
display_regions <- c("Center", "North", "South")
db_regions <- c("CENTRO", "NORTE", "SUL")

choice <- menu(display_regions, title = "Select the region you want to analyze:")

if(choice == 0) stop("Execution canceled.")

target_db_region <- db_regions[choice]
target_display_region <- display_regions[choice]

cat("\n=========================================\n")
cat("Generating plots for:", target_display_region, "Region\n")
cat("=========================================\n")

# Filter the dataset for the selected region using the database key
plot_data <- plantgro.harv_ALL %>% filter(Region == target_db_region)

# --- B. DEFINE PLOT VARIABLES ---
month_names  <- c("April", "May", "June", "July", "August", "September", "October", "November")
custom_order <- c("EN", "N", "LA")
custom_colors <- c("EN" = "#F8766D", "N" = "grey", "LA" = "#619CFF")
month_levels <- c(month_names, "Entire Season")

# --- C. GENERATE THE FINAL PLOT ---
final_plot <- ggplot(plot_data, aes(x = factor(classification, levels = custom_order), y = Value)) +
  geom_boxplot(aes(fill = classification)) +
  labs(
    x = "ENSO Phase", 
    y = "Yield Value",
    title = paste("Regional Sugarcane Yield Anomalies During Extreme ENSO Phases -", target_display_region, "Region")
  ) +
  theme_bw() +
  theme(legend.position = "none") +
  scale_fill_manual(values = custom_colors) +
  facet_grid(Variable ~ factor(harv.month, levels = month_levels), scales = 'free_y')

print(final_plot)

# ==============================================================================
# 4. DYNAMIC SAVE (Optional)
# ==============================================================================
# output_file <- file.path("C:/Users/jgspe/Documents/Brazil_ENSO_Sugarcane/Visualizations", 
#                          paste0("Yield_Anomalies_ENSO_", target_display_region, ".png"))
# ggsave(output_file, plot = final_plot, width = 12, height = 8, dpi = 300)