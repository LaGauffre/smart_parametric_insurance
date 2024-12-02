import numpy as np
import itertools
import pandas as pd
from scipy.optimize import root_scalar
import matplotlib.pyplot as plt
import time

def ft_compound_poisson(p, L):
    lam = sum(p)
    return lambda theta: np.exp(lam * ( sum(p * np.exp(theta * L)) / lam -1))

def loss_distribution(L, p, method, R = 10000, decimal=8):
    p = p[np.argsort(L)]   
    L = np.sort(L)
    n = len(L)
    if method == "simulation":
        I = np.random.binomial(1, p, size=(R, n))
        X = np.sum(I * L, axis=1)

        
        prob_X = [sum(np.array(X) == x) / R  for x in range(sum(L) + 1)]
        supp_X = np.arange(0, sum(L)+1, 1)[np.array(prob_X) != 0]
        prob_X = np.array(prob_X)[np.array(prob_X) != 0]

        return(supp_X, prob_X)
    elif method == "analytical":
        all_vectors = np.array(list(itertools.product([0, 1], repeat=n)))
        # # Compute the potential loss X for all possible vectors
        supp_X_temp = np.dot(all_vectors, L)
        prob_X_temp  = np.prod(p*all_vectors + (1-all_vectors) * (1-p), axis=1)
        # # Calculate the support and probability distribution
        supp_X, indices = np.unique(supp_X_temp, return_inverse=True)
        prob_X = np.array([sum(prob_X_temp[indices == k]) for k in range(len(supp_X))])


        return(supp_X, prob_X)
    elif method == "recursive":
        # Initialize probability distribution and support
        max_loss = int(sum(L))
        prob_X = np.zeros(max_loss + 1)
        prob_X[0] = np.exp(np.sum(np.log(1 - p)))
        supp_X = np.arange(0, max_loss + 1)

        # Initialize temporary array for v
        v = np.zeros((n, max_loss + 1))

        # Dynamic programming approach
        for x in range(1, max_loss + 1):
            for k in range(n):
                if x >= L[k]:
                    # Only compute v[k, x] if x >= L[k]
                    v[k, x] = round(p[k] / (1 - p[k]) * (L[k] * prob_X[x - L[k]] - v[k, x - L[k]]), decimal)
                    
            # Calculate probability for current loss amount
            prob_X[x] = np.sum(v[:, x]) / x

        # Filter out zero probabilities
        non_zero_indices = prob_X != 0
        supp_X = supp_X[non_zero_indices]
        prob_X = prob_X[non_zero_indices]
        return(supp_X, prob_X)
    elif method == "approximative":
        ft = ft_compound_poisson(p, L)
        N = sum(L) - 1 
        sk = np.arange(0, N+1, 1) * 2 * np.pi / (N+1)
        M_X = np.array([ft(1j * s) for s in sk])
    
        prob_X_fft = np.real(np.dot(np.array([np.array([np.exp(- 1j * s * l) for s in sk]) for l in np.arange(0, N + 1, 1)]) / (N + 1), M_X))
        supp_X_fft = np.arange(0, len(prob_X_fft), 1)
        return(supp_X_fft, prob_X_fft)

def cdf_X(supp_X, prob_X):
    return lambda x: np.sum(prob_X[supp_X <= x])

def quantile(alpha, supp_X, F_X):
    func_to_solve =  lambda x: F_X(x) - alpha
    result = root_scalar(func_to_solve, bracket=[0, max(supp_X)], method='bisect', xtol=1e-6)
    return(result.root)



