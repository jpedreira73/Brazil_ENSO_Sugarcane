# Brazil ENSO Sugarcane: FAIR Data Pipeline & Yield Simulations

## Overview
This repository contains the data processing pipeline, analytical scripts, and relational database architecture designed to assess the impact of the El Niño-Southern Oscillation (ENSO) on sugarcane agronomic performance in Brazil's Center-South region. 

By transitioning highly dimensional, multi-decadal historical weather and crop simulation data from disparate flat files into a structured, FAIR-compliant (Findable, Accessible, Interoperable, and Reusable) system, this project enables seamless querying and reproducible analysis of regional yield anomalies.

## Research Context
This pipeline supports research examining ENSO's influence on key yield indicators: stalk fresh yield (SFY), sugar yield (SY), and total recoverable sugar (TRS). The underlying data relies on simulations using the CANEGRO/DSSAT model, calibrated for the widely cultivated RB867515 variety. The dataset spans 56 growing seasons (1962–2018), 8 sowing dates, and 24 geographical locations.

## Repository Structure
* **/Data_Raw**: Directory for raw historical weather data from the National Institute of Meteorology (INMET) and unversioned DSSAT/CANEGRO output files. *(Note: Large datasets may be hosted via Zenodo or OneDrive, with access instructions provided here)*.
* **/Data_Processed**: The destination for the harmonized, 3NF normalized `sugarcane_enso.sqlite` database.
* **/Scripts**: Version-controlled Python and R scripts handling the ETL (Extract, Transform, Load) process.
    * `01_data_cleaning.R`: Standardizes formats and flags anomalies.
    * `02_db_insertion.py`: Executes automated database insertions mapping to ICASA standards.
* **/Visualizations**: R scripts designed to pull joined SQL queries from the database to generate analytical plots and evaluate yield variability across El Niño, La Niña, and Neutral phases.

## Key Findings Supported by This Database
The harmonized data structure allows for rapid verification of complex agro-climatic interactions, such as:
* Region-specific patterns where Northern and Central regions exhibit stable SFY and SY across different ENSO phases.
* Consistent reductions in TRS across all regions during El Niño events, driven by increased precipitation and temperatures that adversely impact photosynthesis.
* Statistically significant improvements in TRS (by 2.8%) under La Niña conditions in the Southern region, despite late-season declines in overall stalk fresh yield.

## License
This project is licensed under the MIT License.
