# Load required libraries
library(tidyverse)
library(DSSAT)
library(readxl)

# ==============================================================================
# 1. INTERACTIVE REGION SELECTION
# ==============================================================================
regions <- c("CENTRO", "NORTE", "SUL")
choice <- menu(regions, title = "Select the region you want to process:")

if(choice == 0) stop("Execution canceled.")
selected_region <- regions[choice]

cat("\n=========================================\n")
cat("Processing weather data for region:", selected_region, "\n")
cat("=========================================\n")

# ==============================================================================
# 2. LOOP PARAMETERS
# ==============================================================================
month_abbrs <- c("ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OCT", "NOV")
month_names <- c("April", "May", "June", "July", "August", "September", "October", "November")

base_dir_class <- "C:/Users/jgspe/OneDrive/Documents/IC BR"
base_dir_dssat <- file.path("C:/Users/jgspe/OneDrive/Documents/IC BR/Resultados - Xavier", selected_region)

# ==============================================================================
# 3. OPTIMIZED PROCESSING FUNCTION (Reads, Cleans, and Joins Data)
# ==============================================================================
process_month <- function(abbr, month_name) {
  cat("Extracting and processing:", abbr, "...\n")
  
  # Define exact paths
  path_class <- file.path(base_dir_class, paste0("CLASSIFICACAO_", abbr, ".xlsx"))
  path_dssat <- file.path(base_dir_dssat, paste0("Summary_", abbr, ".OUT"))
  
  # Read classification file and align column names for joining
  df_class <- read_excel(path_class, sheet = "Sheet1") %>%
    rename(HYEAR = YEAR)
  
  # Read DSSAT Summary file and cut RAM usage immediately
  df_dssat <- DSSAT::read_output(path_dssat) %>%
    select(HYEAR, TMAXA, TMINA, SRADA, PRCP) %>%
    # Join ENSO classification dynamically
    left_join(df_class, by = "HYEAR") %>%
    mutate(
      harv.month = month_name,
      classification = ifelse(classification == "N", "NE", classification)
    )
  
  return(df_dssat)
}

# ==============================================================================
# 4. EXECUTE LOOP AND COMBINE DATA
# ==============================================================================
weather_monthly <- map2_dfr(month_abbrs, month_names, process_month)

# Pivot longer for plotting and analysis
weather.harv_ALL <- weather_monthly %>%
  filter(!is.na(classification)) %>% # Remove any years without classification
  pivot_longer(
    cols = c(TMAXA, TMINA, SRADA, PRCP), 
    names_to = "Variable", 
    values_to = "Value"
  )

# ==============================================================================
# 5. DESCRIPTIVE STATISTICS
# ==============================================================================
summary_table <- weather.harv_ALL %>%
  group_by(Variable, classification) %>%
  summarise(
    Minimum = min(Value, na.rm = TRUE),
    Q1 = quantile(Value, 0.25, na.rm = TRUE),
    Median = median(Value, na.rm = TRUE),
    Q3 = quantile(Value, 0.75, na.rm = TRUE),
    Maximum = max(Value, na.rm = TRUE),
    .groups = 'drop'
  )

cat("\n=== DESCRIPTIVE STATISTICS ===\n")
print(summary_table)

# ==============================================================================
# 6. PLOTS (GGPLOT2)
# ==============================================================================
custom_order <- c("EN", "NE", "LA") 
custom_colors <- c("EN" = "#F8766D", "NE" = "grey", "LA" = "#619CFF")

# Define custom labels for variables
variable_labels <- c(
  SRADA = "SRAD (MJ m² d)", 
  PRCP = "PRCP (mm)", 
  TMAXA = "TMAX (°C)", 
  TMINA = "TMIN (°C)"
)

# Define limits for each variable
y_limits <- list(
  PRCP = c(0, 3000),
  SRADA = c(10, 25),
  TMAXA = c(20, 35),
  TMINA = c(10, 25)
)

# Create dummy data for setting free_y limits perfectly
dummy_limits <- do.call(rbind, lapply(names(y_limits), function(var) {
  expand.grid(Variable = var, classification = custom_order, Value = y_limits[[var]])
}))

# Generate the faceted boxplot
ggplot(weather.harv_ALL, aes(x = factor(classification, levels = custom_order), y = Value)) +
  geom_boxplot(aes(fill = classification)) +
  geom_blank(data = dummy_limits) +
  labs(x = "", y = "", fill = "ENSO Phenomenon") +
  scale_x_discrete(limits = custom_order) +
  scale_fill_manual(
    values = custom_colors, 
    breaks = c("EN", "NE", "LA")
  ) +
  theme_bw() +
  theme(
    legend.position = "bottom", 
    axis.text.y = element_blank(), 
    axis.ticks.y = element_blank()
  ) +
  facet_wrap(
    ~ Variable, 
    scales = 'free_y', 
    labeller = labeller(Variable = variable_labels),
    ncol = 1,
    strip.position = "right"
  )
