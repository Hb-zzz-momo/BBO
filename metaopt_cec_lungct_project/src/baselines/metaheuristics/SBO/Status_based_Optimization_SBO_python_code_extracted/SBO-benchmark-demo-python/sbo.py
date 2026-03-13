"""
Status-based Optimization: Algorithm and comprehensive performance analysis (SBO)
"""

import numpy as np
import math

def initialization(SearchAgents_no, dim, ub, lb):
    """
    Initialize the population randomly within bounds.
    """
    if np.isscalar(ub):
        ub = ub * np.ones(dim)
    if np.isscalar(lb):
        lb = lb * np.ones(dim)

    Positions = np.random.rand(SearchAgents_no, dim) * (ub - lb) + lb
    return Positions

def BoundaryControl(X, low, up):
    """
    Control boundary constraints.
    """
    N, dim = X.shape

    if np.isscalar(low):
        low = low * np.ones(dim)
    if np.isscalar(up):
        up = up * np.ones(dim)

    for i in range(N):
        for j in range(dim):
            k = np.random.rand() < np.random.rand()

            if X[i, j] < low[j]:
                if k:
                    X[i, j] = low[j]
                else:
                    X[i, j] = np.random.rand() * (up[j] - low[j]) + low[j]

            if X[i, j] > up[j]:
                if k:
                    X[i, j] = up[j]
                else:
                    X[i, j] = np.random.rand() * (up[j] - low[j]) + low[j]
    return X

def RouletteWheelSelection(weights):
    """
    Roulette wheel selection.
    """
    accumulation = np.cumsum(weights)
    p = np.random.rand() * accumulation[-1]
    chosen_index = -1
    for index in range(len(accumulation)):
        if accumulation[index] > p:
            chosen_index = index
            break
    return chosen_index

def SBO(N, MaxFEs, lb, ub, dim, fobj):
    """
    Status-based Optimization (SBO) Algorithm.

    Parameters:
    -----------
    N : int
        Population size
    MaxFEs : int
        Maximum number of function evaluations
    lb : float or numpy.ndarray
        Lower bound(s) of the search space
    ub : float or numpy.ndarray
        Upper bound(s) of the search space
    dim : int
        Dimension of the problem
    fobj : callable
        The objective function to be minimized.
        It should accept a numpy array of shape (1, dim) and return a scalar fitness.

    Returns:
    --------
    tuple : (best_pos, Convergence_curve)
        - best_pos : numpy.ndarray
            The best solution found
        - Convergence_curve : list
            List of best fitness values throughout the optimization
    """

    # INITIALIZATION
    Convergence_curve = []
    FEs = 0

    current_X = initialization(N, dim, ub, lb)
    localElite_X = initialization(N, dim, ub, lb)

    current_Fitness = np.inf * np.ones(N)
    localElite_Fitness = np.inf * np.ones(N)
    social_Fitness = np.inf * np.ones(N)

    for i in range(N):
        current_Fitness[i] = fobj(current_X[i, :].reshape(1, -1))
        FEs += 1
        fitness = fobj(localElite_X[i, :].reshape(1, -1))
        FEs += 1
        if current_Fitness[i] < fitness:
            localElite_X[i, :] = current_X[i, :]
            localElite_Fitness[i] = current_Fitness[i]
        else:
            localElite_Fitness[i] = fitness

    # Sort the localElite population
    sorted_localElite_Fitness_indices = np.argsort(localElite_Fitness)
    sorted_localElite_Fitness = localElite_Fitness[sorted_localElite_Fitness_indices]
    localElite_X = localElite_X[sorted_localElite_Fitness_indices, :]

    best_pos = localElite_X[0, :]
    bestFitness = sorted_localElite_Fitness[0]

    iter_count = 0

    # Social success flag
    flag = np.ones(N, dtype=int)

    while FEs < MaxFEs:
        # Select an individual from the localElite population based on the Roulette selection
        roulette_weights = 1.0 / (sorted_localElite_Fitness + np.finfo(float).eps)
        Roulette_index = RouletteWheelSelection(roulette_weights)
        if Roulette_index == -1:
             Roulette_index = 0 # Default to the best if selection fails

        # Update the current population
        for i in range(N):
            w1 = np.random.randn()
            w2 = np.random.randn()
            # Ensure FEs/MaxFEs is not 0 initially
            fes_ratio = FEs / MaxFEs
            w3 = np.tanh((np.sqrt(np.abs(MaxFEs - np.random.randn() * FEs)) / (i + 1))**(fes_ratio)) # Add 1 since python start from 0
            w4 = np.random.uniform(-w3, w3)

            if np.random.rand() < w3:
                current_X[i, :] = (1 - w1 - w2) * current_X[i, :] + w1 * localElite_X[Roulette_index, :] + w2 * best_pos
            else:
                current_X[i, :] = w4 * ((1 - w1 - w2) * current_X[i, :] + w1 * localElite_X[Roulette_index, :] + w2 * best_pos)

        # Boundary control
        current_X = BoundaryControl(current_X, lb, ub)

        # Upward social
        social_X = np.copy(current_X)

        for i in range(N):
            if flag[i] == 1:
                social_X1 = localElite_X[i, np.random.randint(dim)]
                social_X2 = best_pos[np.random.randint(dim)]
                social_X[i, np.random.randint(dim)] = (social_X1 + social_X2) / 2

        m = np.zeros(dim)
        u = np.random.permutation(dim)
        # Ensure ceil(rand * dim) is at least 1 if dim > 0
        num_dims_to_copy = math.ceil(np.random.rand() * dim) if dim > 0 else 0
        if num_dims_to_copy > 0:
             m[u[:num_dims_to_copy]] = 1

        for i in range(N):
            if flag[i] == 0:
                for j in range(dim):
                    if m[j]:
                        social_X[i, j] = localElite_X[i, j]

        # Greedy selection
        for i in range(N):
            if FEs >= MaxFEs:
                break
            current_Fitness[i] = fobj(current_X[i, :].reshape(1, -1))
            FEs += 1
            if FEs >= MaxFEs:
                break
            social_Fitness[i] = fobj(social_X[i, :].reshape(1, -1))
            FEs += 1

            if social_Fitness[i] < current_Fitness[i]:
                # Social success: apply one-dimension source exchange
                flag[i] = 1
                current_X[i, :] = social_X[i, :]
                current_Fitness[i] = social_Fitness[i]
            else:
                # Social fail: apply multi-dimension source exchange
                flag[i] = 0

        # Update the fitness and the localElite population
        for i in range(N):
            if current_Fitness[i] < localElite_Fitness[i]:
                localElite_Fitness[i] = current_Fitness[i]
                localElite_X[i, :] = current_X[i, :]

        # Sort the localElite fitness and best_pos
        sorted_localElite_Fitness_indices = np.argsort(localElite_Fitness)
        sorted_localElite_Fitness = localElite_Fitness[sorted_localElite_Fitness_indices]
        localElite_X = localElite_X[sorted_localElite_Fitness_indices, :]

        if sorted_localElite_Fitness[0] < bestFitness:
            bestFitness = sorted_localElite_Fitness[0]
            best_pos = localElite_X[0, :]

        # Log progress (optional, matching MATLAB's print frequency)
        if FEs % (N * 1000) == 0:
             print(f'FEs: {FEs:6d}/{MaxFEs}, Best Fitness: {bestFitness:.4e}, Best Pos: {np.array2string(best_pos, precision=4, separator=", ")}')


        Convergence_curve.append(bestFitness)
        iter_count += 1

    return best_pos, Convergence_curve