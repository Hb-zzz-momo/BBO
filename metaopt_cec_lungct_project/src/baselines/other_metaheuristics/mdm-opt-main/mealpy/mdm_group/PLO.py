#!/usr/bin/env python
# Created by "Jona" at 14:26, 08/06/2025 ----------%
#       Email: jona.wzu@gmail.com            %
#       Github: https://github.com/JonaWon       %
# --------------------------------------------------%

import numpy as np
from mealpy.optimizer import Optimizer
from scipy.special import gamma


class OriginalPLO(Optimizer):
    """
    The original version of: Polar Light Optimizer (PLO)

    Examples
    ~~~~~~~~
    >>> import numpy as np
    >>> from mealpy import FloatVar, PLO
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
    >>> model = PLO.OriginalPLO(epoch=1000, pop_size=50)
    >>> g_best = model.solve(problem_dict)
    >>> print(f"Solution: {g_best.solution}, Fitness: {g_best.target.fitness}")
    >>> print(f"Solution: {model.g_best.solution}, Fitness: {model.g_best.target.fitness}")
    """

    def __init__(self, epoch=10000, pop_size=100, **kwargs):
        """
        Args:
            epoch (int): maximum number of iterations, default = 10000
            pop_size (int): number of population size, default = 100
        """
        super().__init__(**kwargs)
        self.epoch = self.validator.check_int("epoch", epoch, [1, 100000])
        self.pop_size = self.validator.check_int("pop_size", pop_size, [5, 10000])
        self.set_parameters(["epoch", "pop_size"])
        self.sort_flag = True

    def levy(self, d):
        """
        Levy flight distribution

        Args:
            d (int): Dimension of the problem
        """
        beta = 1.5
        sigma = (gamma(1 + beta) * np.sin(np.pi * beta / 2) /
                 (gamma((1 + beta) / 2) * beta * 2 ** ((beta - 1) / 2))) ** (1 / beta)
        u = self.generator.normal(0, sigma, d)
        v = self.generator.normal(0, 1, d)
        step = u / np.abs(v) ** (1 / beta)
        return step

    def evolve(self, epoch):
        """
        The main operations (equations) of algorithm. Inherit from Optimizer class

        Args:
            epoch (int): The current iteration
        """
        # Calculate progress percentage for adaptive parameters
        progress_ratio = epoch / self.epoch

        # Calculate mean position of the population
        x_mean = np.mean([agent.solution for agent in self.pop], axis=0)

        # Calculate adaptive weights
        w1 = np.tanh((progress_ratio) ** 4)
        w2 = np.exp(-(2 * progress_ratio) ** 3)

        # E for particle collision
        E = np.sqrt(progress_ratio)

        # Generate random permutation for collision pairs
        A = self.generator.permutation(self.pop_size)

        pop_new = []
        for idx in range(0, self.pop_size):
            # Aurora oval walk
            a = self.generator.uniform() / 2 + 1
            V = np.exp((1 - a) / 100 * epoch)
            LS = V

            # Levy flight movement component
            GS = self.levy(self.problem.n_dims) * (x_mean - self.pop[idx].solution +
                                                   (self.problem.lb + self.generator.uniform(0, 1, self.problem.n_dims) *
                                                    (self.problem.ub - self.problem.lb)) / 2)

            # Update position based on aurora oval walk
            pos_new = self.pop[idx].solution + (w1 * LS + w2 * GS) * self.generator.uniform(0, 1, self.problem.n_dims)

            # Particle collision
            for j in range(self.problem.n_dims):
                if (self.generator.random() < 0.05) and (self.generator.random() < E):
                    pos_new[j] = self.pop[idx].solution[j] + np.sin(self.generator.random() * np.pi) * \
                                 (self.pop[idx].solution[j] - self.pop[A[idx]].solution[j])

            # Ensure the position is within bounds
            pos_new = self.correct_solution(pos_new)
            agent = self.generate_empty_agent(pos_new)
            pop_new.append(agent)

            if self.mode not in self.AVAILABLE_MODES:
                agent.target = self.get_target(pos_new)
                self.pop[idx] = self.get_better_agent(agent, self.pop[idx], self.problem.minmax)

        if self.mode in self.AVAILABLE_MODES:
            pop_new = self.update_target_for_population(pop_new)
            self.pop = self.greedy_selection_population(self.pop, pop_new, self.problem.minmax)