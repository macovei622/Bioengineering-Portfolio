# Computational Bioengineering Portfolio 🧬⚙️

**Author:** Illya Macovei  
**Domain:** Biomedical Engineering, Computational Modeling, Neuroengineering  
**Tech Stack:** Python, MATLAB, Simulink, Signal Processing, PDEs

Welcome to my portfolio of computational bioengineering projects. My focus lies at the intersection of biomechanics, tissue engineering, and neuroprosthetics, using Python, MATLAB, and Simulink to build and evaluate computational models.

## 📘 Project Theory Guide

See the [theory, calculations, methods, alternatives, and limitations for all three projects](./PROJECTS_THEORY_GUIDE.md).

## Software Safety and Lifecycle

See the [educational risk-management and software lifecycle documentation](./docs/software-safety/README.md). It is informed by ISO 14971 and IEC 62304 concepts and is not a claim of compliance, certification, or medical-device readiness.

## 🚀 Projects Overview

### 1. [EMG Gesture Classification](./Project_1_EMG_Processing/EMG.Classification/files)
A Python and MATLAB pipeline for classifying hand gestures from RMS-processed NinaPro DB1 signals.
* **Focus:** Trial-grouped evaluation, time-domain features, LDA, SVM, and Extra Trees.
* **Tech:** Python (NumPy, pandas, scikit-learn), MATLAB.

### 2. [Biomechanical Modeling of the Knee Joint (Simulink)](./Project_2_Knee_Biomechanics)
A dynamic computational model analyzing the passive stabilization of the human knee joint during a normal gait cycle.
* **Focus:** Gait analysis, non-linear ligament viscoelasticity, ACL tear simulation.
* **Tech:** MATLAB, Simulink (Analytical Kinematics/Dynamics without visual solvers).

### 3. [Tissue Engineering Scaffold: 2D Oxygen Diffusion Model](./Project_3_Scaffold_Diffusion)
A Python and MATLAB finite-difference solver for a two-dimensional reaction-diffusion model with manually specified channel geometry.
* **Focus:** Mass transfer, PDEs, and model limitations.
* **Tech:** Python, MATLAB (Vectorized Numerical Computing, Jacobi Iteration, mesh and channel-geometry studies).

---
*🎓 Developed as part of the Biomedical Engineering curriculum at Vinnytsia National Technical University.*