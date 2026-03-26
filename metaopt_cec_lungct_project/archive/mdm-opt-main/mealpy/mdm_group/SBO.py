#!/usr/bin/env python
# Created by "Jona" at 14:26, 08/06/2025 ----------%
#       Email: jona.wzu@gmail.com            %
#       Github: https://github.com/JonaWon       %
# --------------------------------------------------%

import numpy as np
from mealpy.optimizer import Optimizer


class OriginalSBO(Optimizer):
    """
    The original version of: Status-based Optimization (SBO)

    Links:
        1. https://doi.org/10.1016/j.neucom.2025.130603
        2. https://aliasgharheidari.com/SBO.html

    Examples
    ~~~~~~~~
    >>> import numpy as np
    >>> from mealpy import FloatVar, SBO
    >>>
    >>> def objective_function(solution):
    >>>     return np.sum(solution**2)
    >>>
    >>> problem_dict = {
    >>>     "bounds": FloatVar(n_vars=30, lb=(-10.,) * 30, ub=(10.,) * 30, name="delta"),
    >>>     "minmax": "min",
    >>>     "obj_func": objective_function
    >>> }
    >>>
    >>> model = SBO.OriginalSBO(epoch=1000, pop_size=50)
    >>> g_best = model.solve(problem_dict)
    >>> print(f"Solution: {g_best.solution}, Fitness: {g_best.target.fitness}")
    >>> print(f"Solution: {model.g_best.solution}, Fitness: {model.g_best.target.fitness}")

    References
    ~~~~~~~~~~
    [1] Wang, J., Chen, Y., Lu, C., Heidari, A. A., Wu, Z., & Chen, H. (2025). The Status-based
    Optimization: Algorithm and comprehensive performance analysis. Neurocomputing, 130603.
    """

    def __init__(self, epoch: int = 10000, pop_size: int = 100, **kwargs: object) -> None:
        """
        Args:
            epoch (int): maximum number of iterations, default = 10000
            pop_size (int): number of population size, default = 100
        """
        super().__init__(**kwargs)
        self.epoch = self.validator.check_int("epoch", epoch, [1, 100000])
        self.pop_size = self.validator.check_int("pop_size", pop_size, [5, 10000])
        self.set_parameters(["epoch", "pop_size"])
        self.sort_flag = False

    def roulette_wheel_selection(self, weights: np.ndarray) -> int:
        """
        Roulette wheel selection based on weights

        Args:
            weights (np.ndarray): Array of weights for selection

        Returns:
            int: Selected index, -1 if selection fails
        """
        try:
            # Handle edge cases
            if len(weights) == 0:
                return -1

            # Normalize weights to avoid numerical issues
            weights = np.array(weights)
            if np.sum(weights) == 0:
                return 0  # Return first index if all weights are zero

            # Calculate cumulative sum
            accumulation = np.cumsum(weights)
            p = self.generator.random() * accumulation[-1]

            # Find the selected index
            for index in range(len(accumulation)):
                if accumulation[index] > p:
                    return index

            return -1  # Selection failed
        except:
            return -1

    def boundary_control(self, X: np.ndarray) -> np.ndarray:
        """
        Boundary control mechanism from the original SBO algorithm

        Args:
            X (np.ndarray): Population matrix

        Returns:
            np.ndarray: Population with corrected boundaries
        """
        N, dim = X.shape

        for i in range(N):
            for j in range(dim):
                k = self.generator.random() < self.generator.random()

                if X[i, j] < self.problem.lb[j]:
                    if k:
                        X[i, j] = self.problem.lb[j]
                    else:
                        X[i, j] = self.generator.random() * (self.problem.ub[j] - self.problem.lb[j]) + self.problem.lb[j]

                if X[i, j] > self.problem.ub[j]:
                    if k:
                        X[i, j] = self.problem.ub[j]
                    else:
                        X[i, j] = self.generator.random() * (self.problem.ub[j] - self.problem.lb[j]) + self.problem.lb[j]

        return X

    def initialization(self) -> None:
        """
        Initialize the population and local elite population
        """
        if self.pop is None:
            # Initialize current population
            self.pop = self.generate_population(self.pop_size)

            # Initialize local elite population
            self.local_elite_pop = []
            for i in range(self.pop_size):
                # Generate a random solution for local elite
                local_elite_solution = self.generate_agent()

                # Compare with current agent and keep the better one
                if self.pop[i].is_better_than(local_elite_solution, self.problem.minmax):
                    self.local_elite_pop.append(self.pop[i].copy())
                else:
                    self.local_elite_pop.append(local_elite_solution)

            # Initialize social success flags
            self.social_flags = np.ones(self.pop_size, dtype=int)

    def evolve(self, epoch: int) -> None:
        """
        The main operations (equations) of algorithm. Inherit from Optimizer class

        Args:
            epoch (int): The current iteration
        """
        # Get fitness values for local elite population
        local_elite_fitness = np.array([agent.target.fitness for agent in self.local_elite_pop])

        # Sort local elite population by fitness
        sorted_indices = np.argsort(local_elite_fitness)
        sorted_local_elite_fitness = local_elite_fitness[sorted_indices]

        # Select individual from local elite population using Roulette wheel selection
        # Use inverse fitness for minimization problems
        weights = 1.0 / (sorted_local_elite_fitness + np.finfo(float).eps)
        roulette_index = self.roulette_wheel_selection(weights)

        if roulette_index == -1:
            roulette_index = 0  # Fallback to first index
        else:
            roulette_index = sorted_indices[roulette_index]  # Map back to original index

        # Update current population
        current_X = np.array([agent.solution for agent in self.pop])
        N, dim = current_X.shape

        for i in range(N):
            w1 = self.generator.normal()
            w2 = self.generator.normal()
            w3 = np.tanh((np.sqrt(np.abs(self.epoch - self.generator.normal() * epoch)) / (i + 1)) ** (epoch / self.epoch))
            w4 = self.generator.uniform(-w3, w3)

            if self.generator.random() < w3:
                for j in range(dim):
                    current_X[i, j] = ((1 - w1 - w2) * current_X[i, j] +
                                     w1 * self.local_elite_pop[roulette_index].solution[j] +
                                     w2 * self.g_best.solution[j])
            else:
                for j in range(dim):
                    current_X[i, j] = w4 * ((1 - w1 - w2) * current_X[i, j] +
                                          w1 * self.local_elite_pop[roulette_index].solution[j] +
                                          w2 * self.g_best.solution[j])

        # Boundary control
        current_X = self.boundary_control(current_X)

        # Update population solutions
        for i in range(N):
            self.pop[i].solution = current_X[i].copy()

        # Upward social mechanism
        social_X = current_X.copy()

        # For agents with social success flag = 1 (one-dimension source exchange)
        for i in range(N):
            if self.social_flags[i] == 1:
                social_X1 = self.local_elite_pop[i].solution[self.generator.integers(0, dim)]
                social_X2 = self.g_best.solution[self.generator.integers(0, dim)]
                social_X[i, self.generator.integers(0, dim)] = (social_X1 + social_X2) / 2

        # For agents with social success flag = 0 (multi-dimension source exchange)
        m = np.zeros(dim, dtype=int)
        u = self.generator.permutation(dim)
        selected_dims = int(np.ceil(self.generator.random() * dim))
        if selected_dims > 0:
            m[u[:selected_dims]] = 1

        for i in range(N):
            if self.social_flags[i] == 0:
                for j in range(dim):
                    if m[j] == 1:
                        social_X[i, j] = self.local_elite_pop[i].solution[j]

        # Create social population following mealpy pattern
        social_pop = []
        for i in range(N):
            social_agent = self.generate_empty_agent(social_X[i])
            social_pop.append(social_agent)

            # Handle fitness evaluation based on execution mode (following AEO pattern)
            if self.mode not in self.AVAILABLE_MODES:
                # Sequential mode: evaluate immediately and perform greedy selection
                social_agent.target = self.get_target(social_X[i])
                self.pop[i].target = self.get_target(current_X[i])

                # Greedy selection and update social flags
                if social_agent.is_better_than(self.pop[i], self.problem.minmax):
                    # Social success: apply one-dimension source exchange
                    self.social_flags[i] = 1
                    self.pop[i] = social_agent.copy()
                else:
                    # Social fail: apply multi-dimension source exchange
                    self.social_flags[i] = 0

                # Update local elite population
                if self.pop[i].is_better_than(self.local_elite_pop[i], self.problem.minmax):
                    self.local_elite_pop[i] = self.pop[i].copy()

        # Handle parallel modes (process, thread, swarm)
        if self.mode in self.AVAILABLE_MODES:
            # Update fitness for both populations in parallel
            self.pop = self.update_target_for_population(self.pop)
            social_pop = self.update_target_for_population(social_pop)

            # Greedy selection and update social flags
            for i in range(N):
                if social_pop[i].is_better_than(self.pop[i], self.problem.minmax):
                    # Social success: apply one-dimension source exchange
                    self.social_flags[i] = 1
                    self.pop[i] = social_pop[i].copy()
                else:
                    # Social fail: apply multi-dimension source exchange
                    self.social_flags[i] = 0

            # Update local elite population
            for i in range(N):
                if self.pop[i].is_better_than(self.local_elite_pop[i], self.problem.minmax):
                    self.local_elite_pop[i] = self.pop[i].copy()