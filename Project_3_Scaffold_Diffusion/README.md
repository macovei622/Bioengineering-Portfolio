# 2D Scaffold Oxygen Diffusion Model

## Python implementation

[`python/scaffold_diffusion.py`](./python/scaffold_diffusion.py) ports the
MATLAB model's two masks, fixed-concentration boundaries, zero-order oxygen
consumption, clipped Jacobi updates, convergence check, tissue-based necrosis
percentage, and full-grid viable-tissue percentage. The numerical parameters
and expected output percentages are preserved.

From the repository root:

```bash
python3 -m pip install -r requirements-python.txt
python3 Project_3_Scaffold_Diffusion/python/scaffold_diffusion.py
```

The command prints both scenarios' metrics and iteration/convergence status,
then writes `scaffold_diffusion_results.png` next to the Python script. Use
`--output PATH` to choose a different figure path.

To check whether the reported percentages depend strongly on grid resolution,
run the mesh study:

```bash
python3 Project_3_Scaffold_Diffusion/python/scaffold_diffusion.py --mesh-study
```

It compares 100 × 100, 150 × 150, and 200 × 200 grids while scaling channel
width with grid spacing to keep the physical geometry approximately fixed.
This is a numerical sensitivity check, not a validation of the biological
assumptions or evidence that the manually selected channel pattern is optimal.
In the current run, solid-tissue hypoxia changed from **31.8%** to **31.0%**
across 100 × 100 to 200 × 200; the channelized result stayed at **0.0%**.
Thus, the headline comparison is stable across these resolutions for the
current parameters, although viability and removed-area percentages shift
slightly with the discretized geometry.

To compare channel widths and spacing in the same simplified model, run:

```bash
python3 Project_3_Scaffold_Diffusion/python/scaffold_diffusion.py --optimize-channels
```

The search tests regular patterns with 1–5 channels in each direction and
channel widths of 1, 3, 5, 7, 9, or 11 grid cells. Designs are ranked by viable
tissue as a fraction of the complete scaffold cross-section, while also
reporting tissue area and hypoxia. This is a small design-space search, not a
global optimum or a biological validation. In this model, a channel is an
oxygen boundary at fixed concentration; the calculation does not model blood
flow, vessel maturation, endothelial cells, or necrosis-driven tissue damage.
For the current parameters and 150 × 150 grid, the best tested design is one
1-pixel-wide channel in each direction: **96.0% of the grid** remains viable,
with **0.0%** of the modeled tissue below the hypoxia threshold. The original
three-channel-per-direction, 7-pixel-wide design leaves **71.7%** viable grid
area. The best design is only the winner among these tested regular patterns;
the one-pixel channel is grid-dependent and should not be interpreted as a
validated physical vessel diameter. The command also saves a comparison
figure to `scaffold_diffusion_results.png`.

Run the focused checks with:

```bash
python3 -m pytest Project_3_Scaffold_Diffusion/python/test_scaffold_diffusion.py
```

The MATLAB script remains available as the original implementation.

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

The 26.4% figure is the fraction of the original **tissue mask** replaced by
channels, not 26.4 percentage points of the whole 150 × 150 cross-section.
The absolute comparison is **66.8% viable grid area** for the solid design
versus **71.7%** for the original channelized design. Do not infer a 73.6%
viable fraction by subtracting 26.4 and 0.0 from 100: the percentages have
different denominators, and the outer boundary is not tissue either. The
model counts empty channels as non-cell-bearing space; it does not simulate
them becoming blood vessels or endothelial tissue.

These are numerical outputs for the selected geometry and parameters, not a proof of an optimized design or a biological outcome.
The checked-in heatmap predates these wording corrections; regenerate its labels from the current MATLAB script before using it as a project figure.

## Limitations

* The geometry and solver are two-dimensional; no 3D transport is modeled.
* The optional grid search compares only regular straight channel patterns; no branching biomimetic topology optimization is performed.
* The solver clips negative concentrations to zero. This is a simplified treatment of depletion for the zero-order consumption model.
* The model does not simulate necrosis over time, toxic byproducts, or damage spreading to neighboring viable tissue.
* The mesh study checks spatial resolution but does not validate biological parameters. The reported percentages depend on material properties, oxygen supply, consumption, and the hypoxia threshold.

## 🚀 How to Run
For MATLAB, execute `scaffold_diffusion.m`. For Python, use the command shown
above; add `--mesh-study` or `--optimize-channels` to run those analyses.