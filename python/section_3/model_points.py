# from scipy.stats import gamma, norm
import numpy as np
# import scipy.stats as st
import math as ma
from scipy.stats import norm
import pandas as pd

def pmf_Sn(S_Zs, p_Zs):
    M = sum([max(S_Z) for S_Z in S_Zs])+1
    
    sk = np.arange(0, M, 1) * 2 * ma.pi / M
    F = np.matrix([np.exp(1j * s * np.arange(0, M, 1)) for s in sk])
    inv_F = np.matrix([np.exp(-1j * sk * l ) for l in np.arange(0, M, 1)]) / M
    M_Sn = lambda s: np.prod(np.array([p_Z@np.exp(s * S_Z) for S_Z, p_Z in zip(S_Zs, p_Zs)]))
    M_Sn_s = np.array([M_Sn(s * 1j) for s in sk])
    return(np.array(np.real(inv_F @ M_Sn_s)).flatten())

def quantile_Sn(pmf_Sn, alpha):
    return np.argmax(np.cumsum(pmf_Sn) >= alpha)

def theta_polynomial(T, station):
    if station == "MARSEILLE-MARIGNANE":
        coeffs = np.array([6.18664665e-02,  1.27906744e-03, -2.20818418e-05,  1.09525424e-07, -1.60548258e-10])
    elif station == "STRASBOURG-ENTZHEIM":
        coeffs = np.array([ 7.65793410e-02, -3.22886973e-04,  1.30842364e-05, -6.66875937e-08, 9.17813311e-11])
    return np.polyval(coeffs[::-1], T)

def get_MPs(portfolio):
    unique_combinations = portfolio[['T', 'station']].drop_duplicates()
    MPs = []
    for _, row in unique_combinations.iterrows():
        T, station = row['T'], row['station']
        subset_row = portfolio[(portfolio['T'] == T) & (portfolio['station'] == station)]
        grouped_row = subset_row.groupby(['theta', 'T', 'station'], as_index=False).agg({'l': 'sum'})
        grouped_row = grouped_row.sort_values(by='theta', ascending=False)
        grouped_row = pd.concat([pd.DataFrame({'theta': [1], 'l': [0], 'T': [T], 'station': [station]}), grouped_row], ignore_index=True)
        grouped_row['l'] = grouped_row['l'].cumsum()
        grouped_row['theta'] = grouped_row['theta'] - grouped_row['theta'].shift(-1, fill_value=0)
        S_Z = grouped_row['l'].to_numpy()
        p_Z = grouped_row['theta'].to_numpy()
        MPs.append({
            "MP#": len(MPs) + 1,
            "T": T,
            "station": station,
            "S_Z": S_Z,
            "p_Z": p_Z
        })
    return(MPs)

def compute_stat_MP(S_Z, p_Z):
    mean = p_Z@S_Z
    var = p_Z @(S_Z - mean)**2
    skew, kurt = p_Z@(S_Z - mean)**3 / var**(3/2), p_Z@(S_Z - mean)**4 / var**2 - 3
    excess_kurt = kurt - 3
    return(mean, var, skew, excess_kurt)

def compute_stat_Sn(stats_mat):
    means, vars, skews, excess_kurts = stats_mat[:, 0], stats_mat[:, 1], stats_mat[:, 2], stats_mat[:, 3]
    mean_Sn, var_Sn  = np.sum(means), np.sum(vars)
    skew_Sn = np.sum(skews * np.sqrt(vars)**3) / np.sqrt(var_Sn)**3
    excess_kurt_Sn = np.sum(excess_kurts * vars**2) / (var_Sn**2)
    return(mean_Sn, var_Sn, skew_Sn, excess_kurt_Sn)
    
def CF_approximation(stats_Sn, alpha):
    mean_Sn, var_Sn, skew_Sn, excess_kurt_Sn = stats_Sn
    y = norm.ppf(alpha, 0, 1)
    CF1 = np.sqrt(var_Sn) * y +  mean_Sn
    CF2 = np.sqrt(var_Sn)*(y + (y**2 - 1) / 6 * skew_Sn) +  mean_Sn 
    CF3 = np.sqrt(var_Sn)*(y +
    (y**2 - 1) / 6 * skew_Sn + (y**3 - 3 * y) / 24 * excess_kurt_Sn + skew_Sn**2 * (-2 * y**3 + 5 * y) / 36) + mean_Sn
    return(CF1, CF2, CF3)

def compute_Quantiles(MPs, alphas):
    
    S_Zs, p_Zs = [d['S_Z'] for d in MPs], [d['p_Z'] for d in MPs]
    stats_mat = np.array([compute_stat_MP(S_Z, p_Z) for S_Z, p_Z in zip(S_Zs, p_Zs)])
    stats_Sn = compute_stat_Sn(stats_mat)
    pmf_Sn_fft = pmf_Sn(S_Zs, p_Zs)
    # CF1, CF2, CF3 = 
    Q_mat = np.array([CF_approximation(stats_Sn, alpha) for alpha in alphas])
    Q_Sn = np.array([quantile_Sn(pmf_Sn_fft, alpha) for alpha in alphas])
    Q_mat = np.column_stack((Q_mat, Q_Sn))
    Q_df = pd.DataFrame(Q_mat.T, columns=["Q" + str(alpha) for alpha in alphas])
    Q_df["method"] = ["CF_1", "CF_2", "CF_3", "FFT"]

    Q_diff_mat   = (Q_mat - Q_Sn[:, None]) / Q_Sn[:, None]
    Q_diff_df = pd.DataFrame(Q_diff_mat.T, columns=["diff_Q" + str(alpha) for alpha in alphas])
    Q_diff_df["method"] = ["CF_1", "CF_2", "CF_3", "FFT"]
    res = pd.merge(Q_df, Q_diff_df, on="method", suffixes=("", "_diff"))
    res["n"] = len(MPs)
    return(res)

