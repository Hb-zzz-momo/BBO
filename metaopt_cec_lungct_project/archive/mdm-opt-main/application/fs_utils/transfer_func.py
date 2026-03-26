#!/usr/bin/env python
# Created by "Jona" at 14:26, 08/06/2025 ----------%
#       Email: jona.wzu@gmail.com            %
#       Github: https://github.com/JonaWon       %
# --------------------------------------------------%

import numpy as np
from scipy.special import erf  # scipy's erf works with arrays


# Sigmoid family (S1-S4)
def s1(decision_var):
    """S1: Binary output using sigmoid with a=2 """
    s = 1 / (1 + np.exp(-2 * decision_var))
    return (np.random.random(np.shape(decision_var)) < s).astype(int)

def s2(decision_var):
    """S2: Binary output using sigmoid with a=1 """
    s = 1 / (1 + np.exp(-decision_var))
    return (np.random.random(np.shape(decision_var)) < s).astype(int)

def s3(decision_var):
    """S3: Binary output using sigmoid with a=0.5 """
    s = 1 / (1 + np.exp(-decision_var/2))
    return (np.random.random(np.shape(decision_var)) < s).astype(int)

def s4(decision_var):
    """S4: Binary output using sigmoid with a≈0.333 """
    s = 1 / (1 + np.exp(-decision_var/3))
    return (np.random.random(np.shape(decision_var)) < s).astype(int)

# Hyperbolic tangent family (V1-V4)
def v1(decision_var):
    """V1: Binary output using error function """
    s = np.abs(erf((np.sqrt(np.pi)/2) * decision_var))
    return (np.random.random(np.shape(decision_var)) < s).astype(int)

def v2(decision_var):
    """V2: Binary output using tanh """
    s = np.abs(np.tanh(decision_var))
    return (np.random.random(np.shape(decision_var)) < s).astype(int)

def v3(decision_var):
    """V3: Binary output using algebraic function """
    s = np.abs(decision_var / np.sqrt(1 + decision_var**2))
    return (np.random.random(np.shape(decision_var)) < s).astype(int)

def v4(decision_var):
    """V4: Binary output using arctangent """
    s = np.abs((2/np.pi) * np.arctan((np.pi/2) * decision_var))
    return (np.random.random(np.shape(decision_var)) < s).astype(int)

# GWO-specific transfer function
def gwo(decision_var, a=10, c=0.5):
    """GWO: Standard GWO transfer function"""
    x = 1 / (1 + np.exp(-a * (decision_var - c)))
    return np.where(x < np.random.random(x.shape), 0, 1)