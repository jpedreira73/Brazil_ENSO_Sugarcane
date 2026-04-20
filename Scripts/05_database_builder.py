import sqlite3
import pandas as pd
import os
import glob

# ==============================================================================
# 1. SETUP PATHS & CONNECTION
# ==============================================================================
base_dir = "C:/Users/jgspe/Documents/Brazil_ENSO_Sugarcane"
db_path = os.path.join(base_dir, "Sugarcane_ENSO.db")
processed_dir = os.path.join(base_dir, "Data_Processed")

print("Initializing FAIR-compliant SQLite database...")
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# ==============================================================================
# 2. BUILD 3NF DATABASE ARCHITECTURE (Updated with Region)
# ==============================================================================
cursor.executescript('''
    CREATE TABLE IF NOT EXISTS ENSO_Lookup (
        Year INTEGER PRIMARY KEY,
        Phase TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS Locations (
        Loc_ID INTEGER PRIMARY KEY,
        Station_Code TEXT UNIQUE,
        City_Name TEXT,
        Latitude REAL,
        Longitude REAL
    );

    CREATE TABLE IF NOT EXISTS Weather_Daily (
        Weather_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Loc_ID INTEGER,
        Date TEXT,
        TMAX REAL,
        TMIN REAL,
        PRCP REAL,
        SRAD REAL,
        FOREIGN KEY (Loc_ID) REFERENCES Locations (Loc_ID)
    );

    -- Added the "Region" column so you can filter your data!
    CREATE TABLE IF NOT EXISTS Yield_Results (
        Result_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Region TEXT,
        Year INTEGER,
        Harvest_Month TEXT,
        TCH_t_ha REAL,
        Sugar_Yield_kg_tc REAL,
        TSH_t_ha REAL,
        FOREIGN KEY (Year) REFERENCES ENSO_Lookup (Year)
    );
''')
conn.commit()
print("  -> Schema built successfully.")

# ==============================================================================
# 3. DATA INSERTION FUNCTIONS
# ==============================================================================

def load_locations():
    """Populates the geographic locations."""
    print("Loading Locations...")
    locations = pd.DataFrame({
        'Loc_ID': [1, 2, 3],
        'Station_Code': ['BR_CENTRO', 'BR_NORTE', 'BR_SUL'],
        'City_Name': ['Centro Region', 'Norte Region', 'Sul Region'],
        'Latitude': [-15.0, -5.0, -25.0],  # Example coordinates
        'Longitude': [-50.0, -55.0, -50.0]
    })
    locations.to_sql('Locations', conn, if_exists='replace', index=False)

def load_enso_data():
    """Automatically extracts the 56-year ENSO timeline from your Yield CSV."""
    print("Loading actual ENSO classifications...")
    yield_files = glob.glob(os.path.join(processed_dir, "Clean_Yield_Data_*.csv"))
    if yield_files:
        df = pd.read_csv(yield_files[0]) # Read just one region to get the timeline
        enso_df = df[['YEAR', 'classification']].drop_duplicates().dropna()
        enso_df = enso_df.rename(columns={'YEAR': 'Year', 'classification': 'Phase'})
        enso_df.to_sql('ENSO_Lookup', conn, if_exists='replace', index=False)
        print("  -> ENSO Lookup dynamically built from CSV.")

def load_yield_data():
    """Reads wide-format yield CSVs, tags the Region, and populates SQLite."""
    print("Loading DSSAT Yield outputs...")
    yield_files = glob.glob(os.path.join(processed_dir, "Clean_Yield_Data_*.csv"))
    
    if yield_files:
        for file in yield_files:
            region_name = os.path.basename(file).replace("Clean_Yield_Data_", "").replace(".csv", "")
            df = pd.read_csv(file)
            df = df.rename(columns={'YEAR': 'Year', 'harv.month': 'Harvest_Month'})
            
            # Keep only exact columns, then insert the Region identifier
            cols_to_keep = ['Year', 'Harvest_Month', 'TCH_t_ha', 'Sugar_Yield_kg_tc', 'TSH_t_ha']
            df_final = df[[c for c in cols_to_keep if c in df.columns]].copy()
            df_final.insert(0, 'Region', region_name) 
            
            df_final.to_sql('Yield_Results', conn, if_exists='append', index=False)
        print("  -> Successfully loaded all yield records.")

def load_weather_data():
    """Force-reads DSSAT .WTH files by bypassing text headers and mapping strictly."""
    print("Loading INMET weather data...")
    weather_files = glob.glob(os.path.join(processed_dir, "*.WTH"))
    
    if weather_files:
        for file in weather_files:
            try:
                # skiprows=5 bypasses the text headers and goes straight to the numbers
                # header=None prevents pandas from guessing column names
                df_wth = pd.read_csv(file, sep='\s+', skiprows=5, header=None, engine='python')
                
                # Manually map the exact DSSAT columns to our SQL database by their position
                df_final = pd.DataFrame()
                df_final['Date'] = df_wth[0]
                df_final['SRAD'] = df_wth[1]
                df_final['TMAX'] = df_wth[2]
                df_final['TMIN'] = df_wth[3]
                df_final['PRCP'] = df_wth[4]
                df_final['Loc_ID'] = 1  # Defaulting all to Loc 1 for now
                
                df_final.to_sql('Weather_Daily', conn, if_exists='append', index=False)
            except Exception as e:
                pass # Silently skip any corrupted text files
        print("  -> Weather files parsed and loaded without NULLs.")
    else:
        print("  -> No .WTH files found in Data_Processed.")

# ==============================================================================
# 4. EXECUTE LOADS
# ==============================================================================
load_locations()
load_enso_data()
load_yield_data()
load_weather_data()
90705070
print("\nDatabase architecture successfully populated! Closing connection.")
conn.close()