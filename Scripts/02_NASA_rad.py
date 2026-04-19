import os
import requests
import pandas as pd
from geopy.geocoders import Nominatim
from datetime import datetime
import time

# --- CONFIGURATION ---
OUTPUT_DIR = r"C:\Users\jgspe\UF Dropbox\Joao Pedreira\PAVAN\.weather\radiaiton"
START_YEAR = 1984  # Earliest available NASA solar data
END_YEAR = datetime.now().year

CITIES = [
    "Sorriso, MT, Brazil", "Canarana, MT, Brazil", "Tangará da Serra, MT, Brazil",
    "Formosa, GO, Brazil", "Aragarças, GO, Brazil", "Unaí, MG, Brazil",
    "Rondonópolis, MT, Brazil", "Aracuai, MG, Brazil", "Ipameri, GO, Brazil",
    "Jatai, GO, Brazil", "Uberlândia, MG, Brazil", "Paranaíba, MS, Brazil",
    "Votuporanga, SP, Brazil", "Campo Grande, MS, Brazil", "Franca, SP, Brazil",
    "Juiz de Fora, MG, Brazil", "Presidente Prudente, SP, Brazil", "Ivinhema, MS, Brazil",
    "Ponta Porã, MS, Brazil", "Londrina, PR, Brazil", "Maringá, PR, Brazil",
    "Sorocaba, SP, Brazil", "Ivaí, PR, Brazil", "Irati, PR, Brazil"
]

if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

geolocator = Nominatim(user_agent="uf_ag_researcher_v3")

def fetch_year(lat, lon, year):
    url = "https://power.larc.nasa.gov/api/temporal/daily/point"
    # Logic for current year vs past years
    s_date = f"{year}0101"
    e_date = f"{year}1231" if year < END_YEAR else datetime.now().strftime("%Y%m%d")
    
    params = {
        "parameters": "ALLSKY_SFC_SW_DWN",
        "community": "AG",
        "longitude": lon,
        "latitude": lat,
        "start": s_date,
        "end": e_date,
        "format": "JSON"
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        if response.status_code == 200:
            return response.json()['properties']['parameter']['ALLSKY_SFC_SW_DWN']
        return {}
    except:
        return {}

# --- EXECUTION ---
for city in CITIES:
    print(f"--- Processing {city} ---")
    location = geolocator.geocode(city)
    if not location:
        print(f"Skipping {city}: Coordinates not found.")
        continue

    city_data = []
    for year in range(START_YEAR, END_YEAR + 1):
        print(f"  Fetching {year}...", end="\r")
        data = fetch_year(location.latitude, location.longitude, year)
        if data:
            # Convert dict to dataframe and add to list
            year_df = pd.DataFrame(list(data.items()), columns=['DATE', 'SOLAR_RAD'])
            city_data.append(year_df)
        time.sleep(0.2) # Small delay to be nice to the API

    if city_data:
        full_df = pd.concat(city_data).sort_values('DATE')
        full_df['DATE'] = pd.to_datetime(full_df['DATE'], format='%Y%m%d')
        
        clean_name = city_name_cleaned = city.split(',')[0].replace(' ', '_')
        file_path = os.path.join(OUTPUT_DIR, f"{clean_name}_radiation.csv")
        full_df.to_csv(file_path, index=False)
        print(f"  DONE: Saved {len(full_df)} days to {file_path}")
    else:
        print(f"  FAILED: No data retrieved for {city}.")

print("\nAll tasks finished.")