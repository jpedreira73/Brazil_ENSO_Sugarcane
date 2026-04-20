# Brazil ENSO Sugarcane: FAIR-Compliant Relational Database & Processing Pipeline

## 1. Project Abstract
Understanding the impact of the **El Niño-Southern Oscillation (ENSO)** on sugarcane yield in Brazil requires analyzing highly dimensional datasets over extended timelines. Because ENSO phases are cyclical climatic phenomena spanning 5 to 7 years, this project analyzes an extensive dataset encompassing 56 growing seasons (1962–2018), 8 sowing dates, and 24 geographical locations.

This repository provides a scripted data processing pipeline that harmonizes historical meteorological inputs from the National Institute of Meteorology (**INMET**) with **DSSAT/CANEGRO** crop model simulation outputs into a queryable, version-controlled relational architecture.

## 2. FAIR Compliance & Standards
The project adheres to **FAIR** (Findable, Accessible, Interoperable, Reusable) principles to ensure academic reproducibility:

* **Findable:** Code and schemas are hosted on GitHub with comprehensive documentation.
* **Accessible:** The harmonized data is stored in a **SQLite** database, accessible via standard open-source tools.
* **Interoperable:** Variable naming and database schema map directly to **ICASA** (International Consortium for Agricultural Systems Applications) standards.
* **Reusable:** All processing scripts are released under the **MIT License** with detailed commentary.

## 3. Database Architecture (3NF)
The system transitions data from fragmented flat files into a **Third Normal Form (3NF)** relational database to eliminate redundancy and prevent formatting errors.

### Core Tables:
* **`Locations`**: Metadata for geographical regions (Latitude, Longitude, Elevation).
* **`ENSO_Lookup`**: Historical ENSO phase classifications (El Niño, La Niña, Neutral).
* **`Weather_Daily`**: Daily meteorological observations (TMAX, TMIN, PRCP, SRAD).
* **`Yield_Results`**: CANEGRO simulation results (Stalk Fresh Yield, Total Recoverable Sugar).

### ICASA Variable Mapping:
* **`TCH_t_ha`** maps to **`HWAM`** (Harvest Weight at Maturity).
* **`Sowing_Date`** maps to **`SDAT`** (Sowing Date).
* **`Loc_ID`** maps to **`WSTA`** (Weather Station).

## 4. Technical Pipeline
The scripted pipeline manages data extraction, transformation, and loading (ETL):
1. **Extraction:** Programmatically pulls raw INMET and DSSAT files.
2. **Transformation:** Standardizes units and flags anomalies (converting -99 or NA values to SQL NULLs).
3. **Loading:** Populates the centralized SQLite database for seamless querying via SQL, R, or Python.

## 5. Directory Structure
```text
Brazil_ENSO_Sugarcane/
├── Data_Raw/           # INMET Weather and DSSAT Outputs
├── Data_Processed/     # sugarcane_enso.sqlite
├── Scripts/            # R and Python processing/analysis scripts
├── Visualizations/     # Yield and weather anomaly reports
├── README.md           # Project documentation
└── Data_Dictionary.md  # Detailed table definitions and mappings
