# 2D Scaffold Oxygen Diffusion Model

## 📝 Overview
A two-dimensional steady-state reaction-diffusion model comparing oxygen concentration in a solid tissue mask and a mask with a manually specified regular channel grid. It is a 2D cross-section model, not a 3D scaffold simulation.

## ⚙️ Mathematical Model: Reaction-Diffusion PDE
Instead of using commercial black-box software, I developed a custom numerical solver:
* **Physics:** Fick's Second Law of Diffusion combined with zero-order cellular consumption kinetics ($D \nabla^2 C - R = 0$).
* **Numerical Method:** Central Finite Difference Method (FDM) on a Cartesian grid.
* **Algorithm:** Iterative Jacobi method using vectorized matrix shifts in MATLAB. The outer boundary and manually drawn channels are held at the perfusion concentration.

## 📊 Results for the specified geometries
*(See the [images](./images) folder for the concentration heatmap.)*

**Key Findings:**
* **Solid mask:** The model reports **31.4% necrotic tissue pixels** and viable tissue equal to **66.8% of the full 150 × 150 grid**.
* **Manually channelized mask:** The specified regular channel grid reports **0.0% necrotic tissue pixels** and viable tissue equal to **71.7% of the full grid**.
* The channels remove about **26.4% of the original tissue-mask area**. The 28.3% not counted as viable tissue in the channelized case includes both channels and the outer boundary; it is not the removed-material fraction.

These are numerical outputs for the selected geometry and parameters, not a proof of an optimized design or a biological outcome.
The checked-in heatmap predates these wording corrections; regenerate its labels from the current MATLAB script before using it as a project figure.

## Limitations

* The geometry and solver are two-dimensional; no 3D transport is modeled.
* Channel positions and spacing are manually selected; no topology or parameter optimization is performed.
* The solver clips negative concentrations to zero. This is a simplified treatment of depletion for the zero-order consumption model.
* No mesh-convergence or parameter-sensitivity analysis is included. The reported percentages depend on the grid, parameters, and hypoxia threshold.

## 🚀 How to Run
Execute `scaffold_diffusion.m` in MATLAB. The script is self-contained and generates concentration heatmaps for the two 2D masks.