# Brazil ENSO Sugarcane: FAIR Data Pipeline & Yield Simulations

## Overview
[cite_start]This repository contains the data processing pipeline, analytical scripts, and relational database architecture designed to assess the impact of the El Niño-Southern Oscillation (ENSO) on sugarcane agronomic performance in Brazil's Center-South region[cite: 1, 46]. 

[cite_start]By transitioning highly dimensional, multi-decadal historical weather and crop simulation data from disparate flat files into a structured, FAIR-compliant (Findable, Accessible, Interoperable, and Reusable) system, this project enables seamless querying and reproducible analysis of regional yield anomalies[cite: 7, 9, 13, 33].

## Research Context
[cite_start]This pipeline supports research examining ENSO's influence on key yield indicators: stalk fresh yield (SFY), sugar yield (SY), and total recoverable sugar (TRS)[cite: 54]. [cite_start]The underlying data relies on simulations using the CANEGRO/DSSAT model, calibrated for the widely cultivated RB867515 variety[cite: 55]. [cite_start]The dataset spans 56 growing seasons (1962–2018), 8 sowing dates, and 24 geographical locations[cite: 5, 55].

## Repository Structure
* [cite_start]**/Data_Raw**: Directory for raw historical weather data from the National Institute of Meteorology (INMET) and unversioned DSSAT/CANEGRO output files[cite: 18]. [cite_start]*(Note: Large datasets may be hosted via Zenodo or OneDrive, with access instructions provided here)*[cite: 30, 32].
* [cite_start]**/Data_Processed**: The destination for the harmonized, 3NF normalized `sugarcane_enso.sqlite` database[cite: 19, 25].
* [cite_start]**/Scripts**: Version-controlled Python and R scripts handling the ETL (Extract, Transform, Load) process[cite: 20, 31, 40].
    * [cite_start]`01_data_cleaning.R`: Standardizes formats and flags anomalies[cite: 20, 27].
    * [cite_start]`02_db_insertion.py`: Executes automated database insertions mapping to ICASA standards[cite: 20, 22, 27].
* [cite_start]**/Visualizations**: R scripts designed to pull joined SQL queries from the database to generate analytical plots and evaluate yield variability across El Niño, La Niña, and Neutral phases[cite: 21, 43].

## Key Findings Supported by This Database
The harmonized data structure allows for rapid verification of complex agro-climatic interactions, such as:
* [cite_start]Region-specific patterns where Northern and Central regions exhibit stable SFY and SY across different ENSO phases[cite: 56].
* [cite_start]Consistent reductions in TRS across all regions during El Niño events, driven by increased precipitation and temperatures that adversely impact photosynthesis[cite: 57].
* [cite_start]Statistically significant improvements in TRS (by 2.8%) under La Niña conditions in the Southern region, despite late-season declines in overall stalk fresh yield[cite: 59].

## License
[cite_start]This project is licensed under the MIT License[cite: 37].

## Reference
Pedreira, J. G. S., Fattori Jr., I. M., Vianna, M. S., & Marin, F. R. (2026). [cite_start]Assessing the impact of El Niño-Southern Oscillation on sugarcane yield and quality in Brazil's South-Central Region using the DSSAT-CANEGRO model[cite: 44, 46, 47]. [cite_start]*Theoretical and Applied Climatology*, 157(5)[cite: 44].
