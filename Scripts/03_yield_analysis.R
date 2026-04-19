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
cat("Processing data for region:", selected_region, "\n")
cat("=========================================\n")

# ==============================================================================
# 2. LOOP PARAMETERS
# ==============================================================================
month_abbrs <- c("ABR", "MAI", "JUN", "JUL", "AGO", "SET", "OCT", "NOV")
month_names  <- c("April", "May", "June", "July", "August", "September", "October", "November")

base_dir_class <- "C:/Users/jgspe/OneDrive/Documents/IC BR"
base_dir_dssat <- file.path("C:/Users/jgspe/OneDrive/Documents/IC BR/Resultados - Xavier", selected_region)

# ==============================================================================
# 3. OPTIMIZED PROCESSING FUNCTION (Reads, Clears RAM, and Joins Data)
# ==============================================================================
process_month <- function(abbr, month_name) {
  cat("Extracting and processing:", abbr, "...\n")
  
  # Define exact paths
  path_class <- file.path(base_dir_class, paste0("CLASSIFICACAO_", abbr, ".xlsx"))
  # Note that the abbreviation OCT changes to OUT in the PlantGro file in some cases, 
  # adjust if your file is named PlantGro_OCT.OUT or PlantGro_OUT.OUT
  path_dssat <- file.path(base_dir_dssat, paste0("PlantGro_", abbr, ".OUT"))
  
  # Read classification file
  df_class <- read_excel(path_class, sheet = "Sheet1")
  
  # Read DSSAT, cut RAM usage immediately and aggregate
  df_dssat <- DSSAT::read_output(path_dssat) %>%
    select(DATE, DAP, SUCMD, SMFMD) %>% # ⚡ SPEED MAGIC: Discard the other 30+ useless columns
    filter(DAP == 365) %>%
    mutate(YEAR = year(DATE)) %>%
    group_by(YEAR) %>%
    summarise(
      SMFMD = mean(SMFMD, na.rm = TRUE),
      SUCMD = mean(SUCMD, na.rm = TRUE),
      .groups = 'drop'
    ) %>%
    # Dynamically join ENSO classification using the YEAR key
    left_join(df_class, by = "YEAR") %>%
    mutate(harv.month = month_name)
  
  return(df_dssat)
}

# ==============================================================================
# 4. EXECUTE LOOP AND COMBINE DATA
# ==============================================================================
# map2_dfr applies the process_month function to all 8 months at once
plantgro_monthly <- map2_dfr(month_abbrs, month_names, process_month)

# Create the "Entire Season" row and stack everything
plantgro_total <- plantgro_monthly %>% mutate(harv.month = "Entire Season")
plantgro_raw_all <- bind_rows(plantgro_monthly, plantgro_total)

# ==============================================================================
# 5. CALCULATION OF AGRONOMIC VARIABLES
# ==============================================================================
plantgro.harv_ALL <- plantgro_raw_all %>%
  mutate(
    `TCH (t/ha)` = SMFMD,
    `Sugar Yield (kg/tc)` = (SUCMD * 1000) / SMFMD,
    `TSH (t/ha)` = SUCMD
  ) %>%
  select(YEAR, harv.month, classification, `TCH (t/ha)`, `Sugar Yield (kg/tc)`, `TSH (t/ha)`) %>%
  pivot_longer(
    cols = c(`TCH (t/ha)`, `Sugar Yield (kg/tc)`, `TSH (t/ha)`), 
    names_to = "Variable", 
    values_to = "Value"
  ) %>%
  filter(!is.na(classification)) # Remove null years to prevent chart errors

# ==============================================================================
# 6. DESCRIPTIVE STATISTICS
# ==============================================================================
descriptive_statistics <- plantgro.harv_ALL %>%
  group_by(harv.month, classification, Variable) %>%
  summarise(
    Min = min(Value, na.rm = TRUE),
    Q1 = quantile(Value, 0.25, na.rm = TRUE),
    Median = median(Value, na.rm = TRUE),
    Q3 = quantile(Value, 0.75, na.rm = TRUE),
    Max = max(Value, na.rm = TRUE),
    .groups = 'drop'
  )

cat("\n=== DESCRIPTIVE STATISTICS ===\n")
print(descriptive_statistics)

# ==============================================================================
# 7. PLOTS (GGPLOT2)
# ==============================================================================
custom_order <- c("EN", "N", "LA")
custom_colors <- c("EN" = "#F8766D", "N" = "grey", "LA" = "#619CFF")
month_levels <- c(month_names, "Entire Season")

ggplot(plantgro.harv_ALL, aes(x = factor(classification, levels = custom_order), y = Value)) +
  geom_boxplot(aes(fill = classification)) +
  labs(
    x = "", 
    y = "",
    title = paste("Yield Analysis - Region:", selected_region)
  ) +
  theme_bw() +
  theme(legend.position = "none") +
  scale_fill_manual(values = custom_colors) +
  facet_grid(Variable ~ factor(harv.month, levels = month_levels), scales = 'free_y')