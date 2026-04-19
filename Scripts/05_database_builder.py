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

print(f"Initializing FAIR-compliant SQLite database at: {db_path}")

# Connect to SQLite (this automatically creates the .db file if it doesn't exist)
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# ==============================================================================
# 2. BUILD 3NF DATABASE ARCHITECTURE
# ==============================================================================
# We use executescript to run multiple SQL commands at once
cursor.executescript('''
    -- Table 1: ENSO Classification Lookup
    CREATE TABLE IF NOT EXISTS ENSO_Lookup (
        Year INTEGER PRIMARY KEY,
        Phase TEXT NOT NULL
    );

    -- Table 2: Station Locations
    CREATE TABLE IF NOT EXISTS Locations (
        Loc_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Station_Code TEXT UNIQUE,
        City_Name TEXT,
        Latitude REAL,
        Longitude REAL
    );

    -- Table 3: Daily Weather Data (Linked to Locations)
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

    -- Table 4: DSSAT Yield Outputs (Linked to ENSO)
    CREATE TABLE IF NOT EXISTS Yield_Results (
        Result_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Year INTEGER,
        Harvest_Month TEXT,
        TCH_t_ha REAL,
        Sugar_Yield_kg_tc REAL,
        TSH_t_ha REAL,
        FOREIGN KEY (Year) REFERENCES ENSO_Lookup (Year)
    );
''')
conn.commit()
print("3NF Schema created successfully.")

# ==============================================================================
# 3. DATA INSERTION FUNCTIONS (The "Load" Phase)
# ==============================================================================

def load_enso_data():
    """Populates the ENSO_Lookup table."""
    print("Loading ENSO classifications...")
    # This inserts the historical ENSO baseline. 
    # (Update this dictionary with the exact years from your .xlsx classification files)
    enso_data = pd.DataFrame({
        'Year': [2000, 2001, 2002, 2003, 2004], # Example years
        'Phase': ['LA', 'NE', 'EN', 'NE', 'NE']
    })
    
    # Push to SQLite. 'append' adds to the table, 'replace' would drop the schema.
    enso_data.to_sql('ENSO_Lookup', conn, if_exists='append', index=False)


def load_yield_data():
    """Reads processed yield CSVs and populates Yield_Results."""
    print("Loading DSSAT Yield outputs...")
    
    # Find the processed yield CSV (ensure your R script saved its final output)
    yield_files = glob.glob(os.path.join(processed_dir, "*yield*.csv"))
    
    if yield_files:
        df_yield = pd.read_csv(yield_files[0])
        
        # Ensure column names map perfectly to the SQL schema
        df_yield = df_yield.rename(columns={
            'YEAR': 'Year',
            'harv.month': 'Harvest_Month',
            'TCH (t/ha)': 'TCH_t_ha',
            'Sugar Yield (kg/tc)': 'Sugar_Yield_kg_tc',
            'TSH (t/ha)': 'TSH_t_ha'
        })
        
        # We drop the 'classification' column here because 3NF architecture dictates 
        # that ENSO phase is retrieved via the Foreign Key (Year) from the ENSO_Lookup table.
        if 'classification' in df_yield.columns:
            df_yield = df_yield.drop(columns=['classification'])
            
        df_yield.to_sql('Yield_Results', conn, if_exists='append', index=False)
        print(f"Loaded {len(df_yield)} yield records.")
    else:
        print("No yield CSV found in Data_Processed. Skipping.")


def load_weather_data():
    """Reads processed INMET .csv/.wth files and populates Weather_Daily."""
    print("Loading INMET weather data...")
    
    weather_files = glob.glob(os.path.join(processed_dir, "*.csv")) + glob.glob(os.path.join(processed_dir, "*.WTH"))
    
    if weather_files:
        # Example of loading a single file. For multiple files, you would loop this.
        for file in weather_files:
            try:
                # Adjust delimiters based on your WTH format (whitespace vs comma)
                df_weather = pd.read_csv(file, sep=None, engine='python')
                
                # Standardize columns to match SQL schema
                df_weather.columns = [col.upper() for col in df_weather.columns]
                
                # Map Loc_ID (Assuming '1' for the primary station right now)
                df_weather['Loc_ID'] = 1 
                
                # Filter down to the exact columns needed for the DB
                cols_to_keep = ['Loc_ID', 'DATE', 'TMAX', 'TMIN', 'PRCP', 'SRAD']
                df_weather = df_weather[[c for c in cols_to_keep if c in df_weather.columns]]
                
                df_weather.to_sql('Weather_Daily', conn, if_exists='append', index=False)
            except Exception as e:
                print(f"Could not load {os.path.basename(file)}: {e}")
                
        print(f"Finished parsing weather files.")
    else:
        print("No weather files found in Data_Processed. Skipping.")

# ==============================================================================
# 4. EXECUTE LOADS
# ==============================================================================
# Note: Ensure your R scripts saved the final DataFrames into Data_Processed
# before running these load functions!

# load_enso_data()
# load_yield_data()
# load_weather_data()

print("Database architecture successfully built. Closing connection.")
conn.close()