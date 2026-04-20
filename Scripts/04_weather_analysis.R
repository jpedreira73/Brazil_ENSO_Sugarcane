# ==============================================================================
# 08_automated_reports.R
# Final Reproducible Pipeline for ENSO-Driven Sugarcane Simulations
# ==============================================================================
library(tidyverse)
library(DBI)
library(RSQLite)

# ==============================================================================
# 1. SETUP PATHS & DATABASE CONNECTION
# ==============================================================================
base_dir <- "C:/Users/jgspe/Documents/Brazil_ENSO_Sugarcane"
db_path <- file.path(base_dir, "Sugarcane_ENSO.db")
output_dir <- file.path(base_dir, "Automated_Plots") # Folder for FAIR deliverables [cite: 38]

if(!dir.exists(output_dir)) dir.create(output_dir)

cat("Connecting to the FAIR database...\n")
conn <- dbConnect(RSQLite::SQLite(), db_path)

# ==============================================================================
# 2. DATA EXTRACTION & AGGRESSIVE CLEANING
# ==============================================================================
# 2A. Fetch Yield Data [cite: 26, 41]
yield_query <- "
  SELECT Y.Region, Y.Year AS YEAR, Y.Harvest_Month AS 'harv.month', 
         E.Phase AS classification, Y.TCH_t_ha, Y.Sugar_Yield_kg_tc, Y.TSH_t_ha
  FROM Yield_Results Y
  JOIN ENSO_Lookup E ON Y.Year = E.Year
"
yield_data_all <- dbGetQuery(conn, yield_query) %>%
  mutate(
    classification = str_squish(classification), 
    classification = ifelse(classification %in% c("N", "NE"), "NE", classification)
  )

# 2B. Fetch Daily Weather Data [cite: 26, 27]
weather_data_all <- dbGetQuery(conn, "SELECT Loc_ID, Date, TMAX, TMIN, PRCP, SRAD FROM Weather_Daily")

# 2C. Fetch ENSO Lookup for Weather Mapping
enso_df <- dbGetQuery(conn, "SELECT Year, Phase AS classification FROM ENSO_Lookup") %>%
  mutate(
    classification = str_squish(classification), 
    classification = ifelse(classification %in% c("N", "NE"), "NE", classification)
  )

dbDisconnect(conn)

# ==============================================================================
# 3. PLOT SETTINGS & TEMPLATES
# ==============================================================================
db_regions <- c("CENTRO", "NORTE", "SUL")
display_regions <- c("Center", "North", "South")
loc_ids <- c(1, 2, 3) 

custom_order <- c("EN", "NE", "LA") 
custom_colors <- c("EN" = "#F8766D", "NE" = "grey", "LA" = "#619CFF")

# ICASA-compliant variable labels 
variable_labels <- c(
  SRADA = "SRAD (MJ m² d)", 
  PRCP = "PRCP (mm)", 
  TMAXA = "TMAX (°C)", 
  TMINA = "TMIN (°C)"
)

# Standardized axis limits
y_limits <- list(
  PRCP = c(0, 3000),
  SRADA = c(10, 25),
  TMAXA = c(20, 35),
  TMINA = c(10, 25)
)

dummy_limits <- bind_rows(lapply(names(y_limits), function(var) {
  expand.grid(Variable = var, classification = custom_order, Value = y_limits[[var]])
})) %>%
  mutate(classification = factor(classification, levels = custom_order))

# ==============================================================================
# 4. AUTOMATION LOOP FOR EACH REGION
# ==============================================================================
for (i in 1:length(db_regions)) {
  
  target_db_region <- db_regions[i]
  target_disp_region <- display_regions[i]
  target_loc_id <- loc_ids[i]
  
  cat("\n=========================================\n")
  cat("Processing:", target_disp_region, "Region\n")
  cat("=========================================\n")
  
  reg_weather_data <- weather_data_all %>% filter(Loc_ID == target_loc_id)
  
  if(nrow(reg_weather_data) > 0) {
    
    # ENSURE TYPES ARE NUMERIC BEFORE JOINING
    enso_df$Year <- as.numeric(as.character(enso_df$Year))
    
    # --- UNIVERSAL MATH-BASED DATE PARSER ---
    weather_agg <- reg_weather_data %>%
      mutate(
        raw_val = as.numeric(as.character(Date)),
        # Logic: YYDDD / 1000 gives YY. YYYYDDD / 1000 gives YYYY.
        year_extracted = floor(raw_val / 1000),
        # Final Correction: If extracted year is 2-digits, add century.
        Year = ifelse(year_extracted > 1000, 
                      year_extracted, 
                      ifelse(year_extracted < 50, 2000 + year_extracted, 1900 + year_extracted))
      ) %>%
      group_by(Year) %>%
      summarise(
        PRCP  = sum(PRCP, na.rm = TRUE),   
        SRADA = mean(SRAD, na.rm = TRUE),  
        TMAXA = mean(TMAX, na.rm = TRUE),  
        TMINA = mean(TMIN, na.rm = TRUE),  
        .groups = 'drop'
      )
    
    # --- JOIN AND PIVOT ---
    weather_long <- weather_agg %>%
      inner_join(enso_df, by = "Year") %>% 
      pivot_longer(cols = c(TMAXA, TMINA, PRCP, SRADA), names_to = "Variable", values_to = "Value") %>%
      mutate(classification = factor(classification, levels = custom_order))
    
    # --- DIAGNOSTIC OUTPUT ---
    if(nrow(weather_long) > 0) {
      cat("  -> Successfully matched", length(unique(weather_long$Year)), "years.\n")
      cat("  -> Overlap Range:", min(weather_long$Year), "to", max(weather_long$Year), "\n")
      
      weather_plot <- ggplot(weather_long, aes(x = classification, y = Value)) +
        geom_boxplot(aes(fill = classification)) +
        geom_blank(data = dummy_limits) +
        labs(
          x = "", y = "", fill = "ENSO Phenomenon",
          title = paste("Historical Weather Distribution -", target_disp_region, "Region")
        ) +
        scale_x_discrete(limits = custom_order) +
        scale_fill_manual(values = custom_colors, breaks = custom_order, drop = FALSE) +
        theme_bw() +
        theme(
          legend.position = "bottom", 
          axis.text.y = element_blank(), 
          axis.ticks.y = element_blank()
        ) +
        facet_wrap(
          ~ Variable, scales = 'free_y',
          labeller = labeller(Variable = variable_labels),
          ncol = 1, strip.position = "right"
        )
      
      weather_filename <- file.path(output_dir, paste0("Weather_Analysis_", target_db_region, ".png"))
      ggsave(weather_filename, plot = weather_plot, width = 6, height = 10, dpi = 300)
      cat("  -> Saved Weather Plot\n")
    } else {
      # Debug: If the join fails, show the user the data so we can see the mismatch
      cat("  -> ERROR: No overlapping years found after join.\n")
      cat("     Weather Years in DB:", paste(head(sort(unique(weather_agg$Year))), collapse=", "), "...\n")
      cat("     ENSO Years in DB:", paste(head(sort(unique(enso_df$Year))), collapse=", "), "...\n")
    }
    
  } else {
    cat("  -> Alert: No weather records found in DB for Loc_ID", target_loc_id, "\n")
  }
}