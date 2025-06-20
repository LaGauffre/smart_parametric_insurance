import gzip
import pandas as pd
import matplotlib.pyplot as plt
import approxbayescomp as abc
import numpy as np
import plotly.express as px
import numpy.random as rnd

# # Path to the downloaded .gz file
# gz_file_paths = ['../data/Q_56_previous-1950-2023_RR-T-Vent.csv.gz', '../data/Q_13_previous-1950-2023_RR-T-Vent.csv.gz', 
#                  '../data/Q_67_previous-1950-2023_RR-T-Vent.csv.gz', '../data/Q_69_previous-1950-2023_RR-T-Vent.csv.gz',]

# # Decompress the .gz file and read the CSV content
# dfs = []
# for station in nom_usuels:
#     for gz_file_path in gz_file_paths:
#         with gzip.open(gz_file_path, 'rt', encoding='utf-8') as gz_file:
#             df = pd.read_csv(gz_file, delimiter=';')
#             df_subset = df[(df['NOM_USUEL'] == station)]
#             df_subset = df_subset[['NOM_USUEL', 'LAT', 'LON', 'AAAAMMJJ', 'RR', 'QRR']]
#             df_subset['AAAAMMJJ'] = pd.to_datetime(df_subset['AAAAMMJJ'], format='%Y%m%d')
#             df_subset = df_subset[(df_subset['AAAAMMJJ'].dt.year >= 2000) & (df_subset['AAAAMMJJ'].dt.year <= 2023)]
#             dfs.append(df_subset)
# res_df = pd.concat(dfs)
# # Export the concatenated dataframe to a CSV file
# res_df.to_csv('../data/processed_rainfall_data.csv', index=False)

# Inference of the compound Poisson-Gamma distribution
def pmom_poisson_gamma(obsData):
    lambda_hat = -np.log(np.mean(np.array(obsData) == 0))
    alpha_hat = np.mean(obsData)**2 / (lambda_hat * np.var(obsData) - np.mean(obsData)**2)
    beta_hat = np.mean(obsData) / lambda_hat / alpha_hat
    return((lambda_hat, alpha_hat, beta_hat))

# Simulation of the precipitation data 
def simulate_precipitation(theta, T):
    """
    Generate T observations from the model specified by theta.
    """
    lam, alpha, beta = theta
    freqs = rnd.poisson(lam, size=T)
    Q = np.empty(T, np.float64)
    for t in range(T):
        Q[t] = np.sum(rnd.gamma(alpha, beta, size=freqs[t]))
    return Q

def simulate_precipitation_chat(theta, T):
    """
    Generate T observations from the model specified by theta.
    """
    lam, alpha, beta = theta
    freqs = rnd.poisson(lam, size=T)

    # Pre-allocate the array for Q
    Q = np.zeros(T, dtype=np.float64)

    # Vectorized sum of gamma-distributed values
    max_freq = np.max(freqs)
    gamma_samples = rnd.gamma(alpha, beta, size=(T, max_freq))

    # Sum only the required number of gamma samples for each t
    for t in range(T):
        Q[t] = np.sum(gamma_samples[t, :freqs[t]])

    return Q

