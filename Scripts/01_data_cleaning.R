library(dplyr)
library(readr)
library(stringr)
library(lubridate)
library(purrr)
library(zoo)

# Diretórios
input_dir <- "C:/Users/jgspe/UF Dropbox/Joao Pedreira/PAVAN/.weather"
output_dir <- "C:/Users/jgspe/UF Dropbox/Joao Pedreira/PAVAN/.weather/formated"
nasa_dir <- "C:/Users/jgspe/UF Dropbox/Joao Pedreira/PAVAN/.weather/radiaiton"

if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
}

repeat {
  # 1. Pede o código da estação
  station_code <- readline(prompt = "Enter the station code to process (e.g., 83270): ")
  
  file_pattern <- paste0(".*", station_code, ".*\\.csv$") 
  weather_files <- list.files(path = input_dir, pattern = file_pattern, full.names = TRUE)
  
  if (length(weather_files) == 0) {
    cat("No files found for station code:", station_code, "\n")
  } else {
    file_to_process <- weather_files[1]
    cat("Processing INMET file:", file_to_process, "\n")
    
    # 2. Extrai o nome da cidade (Linha 1)
    header <- read_lines(file_to_process, n_max = 1)
    city_name <- trimws(str_remove(header, "Nome: "))
    city_prefix <- toupper(substr(city_name, 1, 2))
    
    # 3. LER INMET
    df <- read_delim(file_to_process, delim = ";", skip = 10, 
                     locale = locale(encoding = "latin1"), 
                     na = c("", "NA", "null"), col_types = cols(.default = col_character()))
    
    df_clean <- df %>%
      # Força a data para a classe Date estrita (sem fuso horário)
      mutate(Date = as.Date(ymd(`Data Medicao`)),
             Year_2D = format(Date, "%y")) %>%
      filter(!is.na(Date)) %>%
      select(
        Date,
        tmax = matches("MAXIMA|MÁXIMA", ignore.case = TRUE),
        tmin = matches("MINIMA|MÍNIMA", ignore.case = TRUE),
        rain = matches("PRECIPITA", ignore.case = TRUE),
        SRAD = matches("RADIACAO|RADIAÇÃO|INSOLACAO|INSOLAÇÃO", ignore.case = TRUE),
        Year_2D
      ) %>%
      mutate(across(c(tmax, tmin, rain, SRAD), ~ as.numeric(str_replace_all(., ",", "."))))
    
    # 4. CARREGAR E CRUZAR DADOS DA NASA
    nasa_pattern <- paste0("(?i)", city_name) 
    nasa_files <- list.files(path = nasa_dir, pattern = nasa_pattern, full.names = TRUE)
    
    if (length(nasa_files) > 0) {
      cat("Found NASA POWER file:", nasa_files[1], "\n")
      
      nasa_df <- read_csv(nasa_files[1], show_col_types = FALSE, col_types = cols(.default = col_character()))
      colnames(nasa_df)[1] <- "Date_raw"
      
      nasa_df <- nasa_df %>% 
        # Parse super flexível: aceita m/d/y, y-m-d, y/m/d, etc., e força para a classe Date estrita
        mutate(Date = as.Date(parse_date_time(Date_raw, orders = c("mdy", "ymd", "dmy", "Ymd", "Y-m-d")))) %>%
        filter(!is.na(Date)) %>%
        select(Date, NASA_SRAD = matches("SOLAR_RAD|ALLSKY|SRAD|RAD|INSOL", ignore.case = TRUE)[1]) %>%
        mutate(NASA_SRAD = as.numeric(str_replace_all(NASA_SRAD, ",", ".")))
      
      # Verifica quantos SRAD estavam faltando antes do cruzamento
      missing_srad_before <- sum(is.na(df_clean$SRAD))
      
      # Junta as tabelas. 
      df_clean <- df_clean %>%
        left_join(nasa_df, by = "Date") %>%
        mutate(SRAD = coalesce(SRAD, NASA_SRAD)) %>%
        select(-NASA_SRAD)
      
      # Calcula quantos valores foram recuperados com sucesso
      missing_srad_after <- sum(is.na(df_clean$SRAD))
      cat("Successfully filled", (missing_srad_before - missing_srad_after), "missing SRAD values using NASA data!\n")
      
    } else {
      cat("WARNING: No NASA file found for city", city_name, "in", nasa_dir, "\n")
    }
    
    # 5. TRATAMENTO FINAL (Preenchimento de falhas)
    df_clean <- df_clean %>%
      arrange(Date) %>%
      mutate(
        rain = coalesce(rain, 0),
        tmax = zoo::na.approx(tmax, na.rm = FALSE, rule = 2),
        tmin = zoo::na.approx(tmin, na.rm = FALSE, rule = 2)
      )
    
    # 6. EXPORTAR ARQUIVOS CSV POR ANO
    df_split <- split(df_clean, df_clean$Year_2D)
    
    iwalk(df_split, function(data_year, year) {
      data_year <- data_year %>% select(-Year_2D)
      output_name <- file.path(output_dir, paste0(city_prefix, year, ".csv"))
      write_csv(data_year, output_name)
    })
    
    cat("Finished processing station:", station_code, "| Files saved in:", output_dir, "\n")
  }
  
  # 7. PERGUNTAR SE DESEJA CONTINUAR
  run_again <- readline(prompt = "Do you want to process another station? (y/n): ")
  if (tolower(trimws(run_again)) != "y") {
    cat("Ending script.\n")
    break
  }
}