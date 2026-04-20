import sqlite3
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import os

# ==============================================================================
# 1. SETUP PATHS
# ==============================================================================
base_dir = "C:/Users/jgspe/Documents/Brazil_ENSO_Sugarcane"
db_path = os.path.join(base_dir, "Sugarcane_ENSO.db")
viz_dir = os.path.join(base_dir, "Visualizations")

# Automatically create the Visualizations folder if it doesn't exist yet
os.makedirs(viz_dir, exist_ok=True)

# ==============================================================================
# 2. THE REPRODUCIBLE SQL QUERY
# ==============================================================================
print("Connecting to FAIR database...")
conn = sqlite3.connect(db_path)

# This query JOINs the Yield fact table with the ENSO dimension table
# using the 'Year' column as the bridge. It isolates El Niño and La Niña years.
sql_query = """
SELECT 
    Y.Region, 
    Y.Year, 
    E.Phase, 
    Y.TCH_t_ha
FROM Yield_Results Y
JOIN ENSO_Lookup E ON Y.Year = E.Year
WHERE E.Phase IN ('EN', 'LA')
  AND Y.Harvest_Month = 'Entire Season';
"""

# Load the SQL query results directly into a Pandas DataFrame
print("Executing JOIN query...")
df = pd.read_sql_query(sql_query, conn)
conn.close()

# ==============================================================================
# 3. GENERATE VISUALIZATION
# ==============================================================================
print("Generating comparative yield visualization...")

# Setup plot style
plt.figure(figsize=(10, 6))
sns.set_theme(style="whitegrid")

# Create a boxplot to visualize yield variations by Region and ENSO phase
sns.boxplot(
    data=df, 
    x="Region", 
    y="TCH_t_ha", 
    hue="Phase", 
    palette={"EN": "#F8766D", "LA": "#619CFF"} # Consistent with previous R outputs
)

# Formatting for academic readability
plt.title("Regional Sugarcane Yield Anomalies During Extreme ENSO Phases", fontsize=14, fontweight='bold')
plt.xlabel("Geographical Region", fontsize=12)
plt.ylabel("Stalk Fresh Yield / HWAM (Tonnes/Hectare)", fontsize=12)
plt.legend(title="ENSO Phase", loc="lower right")

# ==============================================================================
# 4. SAVE OUT DELIVERABLE
# ==============================================================================
output_file = os.path.join(viz_dir, "Yield_Anomalies_ENSO.png")
plt.savefig(output_file, dpi=300, bbox_inches='tight')

print(f"Success! High-resolution analytical plot saved to: \n{output_file}")
plt.show()