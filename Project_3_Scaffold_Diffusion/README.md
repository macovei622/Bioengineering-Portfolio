# Scaffold Oxygen Diffusion & Topological Optimization

## 📝 Overview
A computational model evaluating oxygen mass transfer in a 3D-bioprinted hydrogel scaffold. The goal is to mathematically resolve the diffusion barrier that leads to central tissue necrosis in avascular implants.

## ⚙️ Mathematical Model: Reaction-Diffusion PDE
Instead of using commercial black-box software, I developed a custom numerical solver:
* **Physics:** Fick's Second Law of Diffusion combined with zero-order cellular consumption kinetics ($D \nabla^2 C - R = 0$).
* **Numerical Method:** Central Finite Difference Method (FDM) on a Cartesian grid.
* **Algorithm:** Iterative Jacobi method utilizing highly optimized, vectorized matrix shifts in MATLAB to bypass slow `for` loops. Dirichlet boundary conditions were applied for perfusion channels.

## 📊 Results & Topology Optimization
*(See the /images folder for concentration heatmaps)*

**Key Findings:**
* **Solid Scaffold:** Due to the quadratic relationship between diffusion time and distance, oxygen fails to reach the center, resulting in **31.4% tissue necrosis**. The absolute yield of living tissue is 66.8% of the total volume.
* **Optimized Porous Scaffold:** Introducing a topologically optimized macro-channel network drastically reduces the maximum diffusion distance. 
* **Engineering Paradox Proven:** Despite removing ~28% of the hydrogel mass to create channels, hypoxia is completely eliminated (**0.0% necrosis**). The absolute yield of viable living tissue paradoxically **increases to 71.7%**.

## 🚀 How to Run
Simply execute `scaffold_diffusion.m` in MATLAB. The script is fully self-contained and will generate the spatial concentration heatmaps automatically.