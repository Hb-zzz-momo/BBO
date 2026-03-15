# Comprehensive Metaheuristic Optimization Framework

[![Python](https://img.shields.io/badge/python-3.8%2B-blue.svg)](https://www.python.org/downloads/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Mealpy](https://img.shields.io/badge/Mealpy-3.0.1-green.svg)](https://github.com/thieu1995/mealpy)
[![Opfunu](https://img.shields.io/badge/Opfunu-1.0.4-orange.svg)](https://github.com/thieu1995/opfunu)

A comprehensive optimization framework that combines state-of-the-art metaheuristic algorithms with benchmark functions for both continuous optimization and feature selection applications. This framework provides researchers and practitioners with a unified platform for optimization algorithm evaluation, comparison, and real-world problem solving.

## 🚀 Key Features

### 🔬 **Optimization Algorithm Library (Mealpy)**

- **100+ Metaheuristic Algorithms** organized by inspiration categories:
  - **Bio-based**: BBO, EOA, IWO, SOA, SOS, TPO, TSA, VCS, WHO, etc.
  - **Evolutionary**: DE, GA, EP, ES, FPA, CRO, MA, SHADE, etc.
  - **Swarm-based**: PSO, GWO, WOA, ABC, ALO, BA, CSO, FA, etc.
  - **Physics-based**: SA, ASO, EO, MVO, TWO, WDO, etc.
  - **Human-based**: BRO, CA, HBO, ICA, QSA, TLO, etc.
  - **Math-based**: AOA, GBO, SCA, PSS, etc.
  - **Music-based**: HS (Harmony Search)
  - **System-based**: AEO, GCO, WCA

### 📊 **Benchmark Function Library (Opfunu)**

- **CEC Competition Functions** (2005-2022)
- **1000+ Test Functions** categorized by:
  - Dimension-based (2D, 3D, N-dimensional)
  - Type-based (Unimodal, Multimodal)
  - Name-based (Classical functions A-Z)

### 🎯 **Feature Selection Application**

- **Binary Optimization** for feature selection
- **Multiple Classifiers**: KNN, SVM, Random Forest, XGBoost, LightGBM, CatBoost, MLP
- **Transfer Functions**: S-shaped and V-shaped functions for binary conversion
- **Cross-validation** with statistical analysis
- **Comprehensive Evaluation Metrics**: Accuracy, Precision, Recall, F1-score, MCC

### 📈 **Advanced Analytics & Visualization**

- **Statistical Analysis**: Wilcoxon signed-rank test, t-test
- **Convergence Curves** with publication-ready plots
- **Boxplot Visualizations** for algorithm comparison
- **Excel Reports** with detailed statistical summaries
- **Parallel Processing** support for faster execution

## 🛠️ Installation

### Prerequisites

- Python 3.8 or higher
- CUDA-compatible GPU (optional, for PyTorch acceleration)

### Quick Installation

```bash
# Clone the repository
git clone https://github.com/JonaWon/mdm-opt.git
cd mdm-opt

# Install dependencies
pip install -r requirements.txt

# For CUDA support (optional)
pip install torch==2.6.0+cu118 --use-deprecated=legacy-resolver --no-cache-dir -f https://mirrors.aliyun.com/pytorch-wheels/cu118
```

### Dependencies

```
catboost==1.2.8
joblib==1.4.2
lightgbm==4.6.0
matplotlib==3.10.1
numpy==2.2.5
pandas==2.2.3
scikit_learn==1.6.1
scipy==1.15.2
xgboost==3.0.0
requests==2.32.3
openpyxl==3.1.5
```

## 🎯 Quick Start

### 1. Continuous Optimization Benchmark

```python
#!/usr/bin/env python
import numpy as np
from mealpy import FloatVar, PSO, GWO, WOA
from opfunu.cec_based.cec2017 import F12017

# Define the optimization problem
def objective_function(solution):
    return np.sum(solution**2)  # Simple sphere function

# Setup problem
problem = {
    "obj_func": objective_function,
    "bounds": FloatVar(lb=(-10,)*30, ub=(10,)*30),
    "minmax": "min",
    "name": "Sphere Function"
}

# Initialize algorithms
algorithms = [
    PSO.OriginalPSO(epoch=100, pop_size=30),
    GWO.OriginalGWO(epoch=100, pop_size=30),
    WOA.OriginalWOA(epoch=100, pop_size=30)
]

# Run optimization
for algo in algorithms:
    best_solution = algo.solve(problem)
    print(f"{algo.__class__.__name__}: Best fitness = {best_solution.target.fitness:.6e}")
```

### 2. CEC Benchmark Validation

```python
# Run comprehensive CEC2017 benchmark
python run_exp.py
```

**Configuration in `run_exp.py`:**

```python
# Experiment parameters
SEARCH_AGENTS_NO = 30      # Population size
DIM = 10                   # Problem dimension
MAX_EPOCHS = 1000          # Maximum iterations
RUNS = 4                   # Independent runs
benchmark_name = 'CEC2017' # CEC benchmark suite

# Select algorithms to test
algorithm_classes = [PLO.OriginalPLO, RIME.OriginalRIME, SBO.OriginalSBO]
```

### 3. Feature Selection Application

```python
# Run feature selection experiments
python application/fs.py
```

**Configuration in `fs.py`:**

```python
# Dataset configuration
DATASETS = ['SpectEW']  # Add your .dat files

# Experiment parameters
EXP_NUM = 10           # Independent runs
FOLDS = 10             # Cross-validation folds
POP_SIZE = 20          # Population size
MAX_ITER = 50          # Maximum iterations

# Algorithm selection
ACTIVE_ALGORITHMS = ['bGWO', 'bPSO']  # Binary algorithms

# Classifier selection
ACTIVE_CLASSIFIERS = ['knn', 'svm', 'rf']  # ML classifiers
```

## 📁 Project Structure

```
mdm-opt/
├── 📁 mealpy/                    # Metaheuristic algorithms library
│   ├── 📁 bio_based/            # Bio-inspired algorithms
│   ├── 📁 evolutionary_based/   # Evolutionary algorithms
│   ├── 📁 swarm_based/          # Swarm intelligence algorithms
│   ├── 📁 physics_based/        # Physics-inspired algorithms
│   ├── 📁 human_based/          # Human behavior-based algorithms
│   ├── 📁 math_based/           # Mathematical algorithms
│   ├── 📁 music_based/          # Music-inspired algorithms
│   ├── 📁 system_based/         # System-based algorithms
│   ├── 📁 mdm_group/            # Modern algorithms group
│   └── 📁 utils/                # Utility functions
├── 📁 opfunu/                   # Benchmark functions library
│   ├── 📁 cec_based/            # CEC competition functions
│   ├── 📁 name_based/           # Classical test functions
│   ├── 📁 type_based/           # Functions by type
│   └── 📁 dimension_based/      # Functions by dimension
├── 📁 application/              # Feature selection application
│   ├── 📄 fs.py                 # Main feature selection script
│   ├── 📁 fs_utils/             # Feature selection utilities
│   └── 📁 fs_exp_result/        # Experimental results
├── 📁 utils/                    # General utilities
│   └── 📄 utils.py              # Visualization and analysis tools
├── 📄 run_exp.py                # Main benchmark script
├── 📄 requirements.txt          # Dependencies
└── 📄 README.md                 # This file
```

## 🔧 Advanced Usage

### Custom Algorithm Implementation

```python
from mealpy import Optimizer
import numpy as np

class CustomAlgorithm(Optimizer):
    def __init__(self, epoch=10000, pop_size=100, **kwargs):
        super().__init__(**kwargs)
        self.epoch = self.validator.check_int("epoch", epoch, [1, 100000])
        self.pop_size = self.validator.check_int("pop_size", pop_size, [5, 10000])
        self.set_parameters(["epoch", "pop_size"])
        self.sort_flag = False

    def evolve(self, epoch):
        """
        The main operations (equations) of algorithm.
        """
        for idx in range(0, self.pop_size):
            # Your custom algorithm logic here
            pos_new = self.pop[idx].solution + np.random.uniform(-1, 1, self.problem.n_dims)
            pos_new = self.correct_solution(pos_new)
            agent = self.generate_empty_agent(pos_new)
            if self.compare_agent(agent, self.pop[idx]):
                self.pop[idx] = agent
```

### Custom Benchmark Function

```python
from opfunu import Benchmark
import numpy as np

class CustomFunction(Benchmark):
    def __init__(self, ndim=None, bounds=None):
        super().__init__(ndim, bounds)

    def evaluate(self, x, *args):
        """
        Custom objective function
        """
        return np.sum(x**2) + 10*np.cos(2*np.pi*x)  # Custom function
```

### Parallel Execution

```python
# Enable parallel processing for faster execution
model = PSO.OriginalPSO(epoch=1000, pop_size=50)
best_solution = model.solve(problem, mode='process', n_workers=4)
```

### Multi-objective Optimization

```python
def multi_objective_function(solution):
    f1 = np.sum(solution**2)           # Minimize sum of squares
    f2 = np.sum((solution - 1)**2)     # Minimize distance from ones
    return [f1, f2]

problem = {
    "obj_func": multi_objective_function,
    "bounds": FloatVar(lb=(-10,)*30, ub=(10,)*30),
    "minmax": "min",
    "obj_weights": [0.5, 0.5]  # Equal weights
}
```

## 📊 Results and Analysis

### Benchmark Results Structure

```
exp_result/
└── 2025-01-08/
    └── PLO-14_26_08/
        ├── 📄 result-PLO-14_26_08.xlsx     # Statistical analysis
        ├── 📄 best_fitness_all.npy         # Raw fitness data
        ├── 📊 F1_convergence.png           # Convergence plots
        ├── 📊 F2_convergence.png
        └── 📊 boxplot_comparison.png       # Algorithm comparison
```

### Feature Selection Results Structure

```
application/fs_exp_result/
└── 2025-01-08/
    └── 14_26_08-Specific-10Runs-SpectEW/
        ├── 📁 Run1-SpectEW/
        │   ├── 📁 knn/
        │   │   ├── 📁 tf_5/
        │   │   │   ├── 📄 knn-ExpRun1-AllFoldResults.csv
        │   │   │   ├── 📄 knn-ExpRun1-Summary.csv
        │   │   │   └── 📄 knn-ExpRun1-StatisticalAnalysis.xlsx
        │   │   └── 📁 all_tfs/
        │   └── 📁 all_classifiers/
        └── 📁 14_26_08-Aggregated-10Runs-SpectEW/  # Aggregated results
```

## 🎨 Visualization Examples

The framework automatically generates publication-ready visualizations:

### Convergence Curves

- **Log-scale fitness evolution** over iterations
- **Multiple algorithm comparison** on single plot
- **Statistical confidence intervals**

### Boxplot Analysis

- **Algorithm performance distribution**
- **Statistical significance indicators**
- **Outlier detection and analysis**

### Feature Selection Metrics

- **Accuracy vs. Number of Features** trade-off
- **Classifier comparison** across algorithms
- **Transfer function effectiveness** analysis

## 🧪 Supported Algorithms

<details>
<summary><b>🧬 Bio-based Algorithms (11)</b></summary>

- **BBO**: Biogeography-Based Optimization
- **BBOA**: Butterfly Optimization Algorithm
- **BMO**: Barnacles Mating Optimizer
- **EOA**: Earthworm Optimization Algorithm
- **IWO**: Invasive Weed Optimization
- **SOA**: Seagull Optimization Algorithm
- **SOS**: Symbiotic Organisms Search
- **TPO**: Tree Physiology Optimization
- **TSA**: Tunicate Swarm Algorithm
- **VCS**: Virus Colony Search
- **WHO**: Wildebeest Herd Optimization

</details>

<details>
<summary><b>🧬 Evolutionary Algorithms (8)</b></summary>

- **CRO**: Coral Reefs Optimization
- **DE**: Differential Evolution
- **EP**: Evolutionary Programming
- **ES**: Evolution Strategy
- **FPA**: Flower Pollination Algorithm
- **GA**: Genetic Algorithm
- **MA**: Memetic Algorithm
- **SHADE**: Success-History Based Adaptive DE

</details>

<details>
<summary><b>🐝 Swarm-based Algorithms (50+)</b></summary>

- **PSO**: Particle Swarm Optimization
- **GWO**: Grey Wolf Optimizer
- **WOA**: Whale Optimization Algorithm
- **ABC**: Artificial Bee Colony
- **ALO**: Ant Lion Optimizer
- **BA**: Bat Algorithm
- **CSO**: Cat Swarm Optimization
- **FA**: Firefly Algorithm
- **And 40+ more swarm intelligence algorithms**

</details>

<details>
<summary><b>⚛️ Physics-based Algorithms (15)</b></summary>

- **SA**: Simulated Annealing
- **ASO**: Atom Search Optimization
- **EO**: Equilibrium Optimizer
- **MVO**: Multi-Verse Optimizer
- **TWO**: Tug of War Optimization
- **WDO**: Wind Driven Optimization
- **And 9+ more physics-inspired algorithms**

</details>

<details>
<summary><b>👥 Human-based Algorithms (17)</b></summary>

- **BRO**: Battle Royale Optimization
- **CA**: Cultural Algorithm
- **HBO**: Human Behavior Optimization
- **ICA**: Imperialist Competitive Algorithm
- **QSA**: Queuing Search Algorithm
- **TLO**: Teaching Learning Optimization
- **And 11+ more human behavior-based algorithms**

</details>

## 🏆 Benchmark Functions

### CEC Competition Functions

- **CEC 2005**: 25 functions (F1-F25)
- **CEC 2008**: 7 functions (F1-F7)
- **CEC 2010**: 20 functions (F1-F20)
- **CEC 2013**: 28 functions (F1-F28)
- **CEC 2014**: 30 functions (F1-F30)
- **CEC 2015**: 15 functions (F1-F15)
- **CEC 2017**: 30 functions (F1-F30)
- **CEC 2019**: 10 functions (F1-F10)
- **CEC 2020**: 10 functions (F1-F10)
- **CEC 2021**: 10 functions (F1-F10)
- **CEC 2022**: 12 functions (F1-F12)

### Classical Test Functions (1000+)

- **Unimodal**: Sphere, Rosenbrock, Sum Squares, etc.
- **Multimodal**: Ackley, Griewank, Rastrigin, Schwefel, etc.
- **Fixed-dimension**: Shekel, Hartman, Branin, etc.

## 📈 Performance Metrics

### Optimization Metrics

- **Best Fitness**: Global optimum found
- **Mean Fitness**: Average performance across runs
- **Standard Deviation**: Algorithm consistency
- **Convergence Rate**: Speed of optimization
- **Success Rate**: Percentage of successful runs

### Feature Selection Metrics

- **Classification Accuracy**: Prediction performance
- **Number of Features**: Dimensionality reduction
- **F1-Score**: Balanced precision and recall
- **Matthews Correlation Coefficient (MCC)**: Overall quality
- **Sensitivity/Specificity**: Class-specific performance

### Statistical Analysis

- **Wilcoxon Signed-Rank Test**: Non-parametric comparison
- **Paired t-test**: Parametric comparison
- **Friedman Test**: Multiple algorithm ranking
- **Effect Size**: Practical significance measurement

## 🤝 Contributing

We welcome contributions to improve the framework! Here's how you can help:

### Adding New Algorithms

1. **Fork the repository**
2. **Create algorithm class** inheriting from `Optimizer`
3. **Implement required methods**: `evolve()`, `__init__()`
4. **Add comprehensive documentation** and examples
5. **Submit pull request** with tests

### Adding New Benchmark Functions

1. **Create function class** inheriting from `Benchmark`
2. **Implement `evaluate()` method**
3. **Add proper bounds and metadata**
4. **Include mathematical description**

### Reporting Issues

- **Bug reports**: Use GitHub issues with detailed description
- **Feature requests**: Propose new functionality
- **Documentation**: Help improve clarity and examples

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 Jona Wong

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

## 🙏 Acknowledgments

This framework builds upon excellent open-source libraries:

- **[Mealpy](https://github.com/thieu1995/mealpy)**: Comprehensive metaheuristic library by Nguyen Van Thieu
- **[Opfunu](https://github.com/thieu1995/opfunu)**: Benchmark functions library by Nguyen Van Thieu
- **[Scikit-learn](https://scikit-learn.org/)**: Machine learning library
- **[NumPy](https://numpy.org/)** & **[SciPy](https://scipy.org/)**: Scientific computing
- **[Matplotlib](https://matplotlib.org/)**: Visualization library

## 📞 Contact

- **Author**: Jona Wong
- **Email**: jona.wzu@gmail.com
- **GitHub**: [@JonaWon](https://github.com/JonaWon)

---

<div align="center">

**⭐ Star this repository if you find it helpful! ⭐**

[🐛 Report Bug](https://github.com/JonaWon/mdm-opt/issues) • [✨ Request Feature](https://github.com/JonaWon/mdm-opt/issues) • [📖 Documentation](https://github.com/JonaWon/mdm-opt/wiki)

</div>
