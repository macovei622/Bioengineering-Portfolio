"""Finite-difference oxygen diffusion model for a 2D tissue scaffold."""

from __future__ import annotations

import argparse
from dataclasses import dataclass, replace
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


@dataclass(frozen=True)
class ModelParameters:
    length_m: float = 2e-3
    grid_size: int = 150
    diffusion_m2_s: float = 2e-9
    consumption_mol_m3_s: float = 2.5e-3
    boundary_concentration_mol_m3: float = 0.2
    hypoxia_threshold_mol_m3: float = 0.02
    tolerance: float = 1e-6
    max_iterations: int = 20_000


def create_masks(
    grid_size: int = 150,
    reference_grid_size: int = 150,
    reference_channel_half_width: int = 3,
    channel_count: int = 3,
) -> tuple[np.ndarray, np.ndarray]:
    """Return the original solid and manually channelized scaffold masks."""
    if (
        grid_size < 5
        or reference_grid_size < 5
        or reference_channel_half_width < 0
        or channel_count < 0
    ):
        raise ValueError("Grid sizes must be at least 5 and channel half-width nonnegative")
    solid = np.ones((grid_size, grid_size), dtype=bool)
    solid[[0, -1], :] = False
    solid[:, [0, -1]] = False
    porous = solid.copy()
    spacing = round(grid_size / (channel_count + 1)) if channel_count else 0
    half_width = round(
        reference_channel_half_width
        * (grid_size - 1)
        / (reference_grid_size - 1)
    )
    for index in range(1, channel_count + 1):
        center = index * spacing - 1
        start = max(0, center - half_width)
        stop = min(grid_size, center + half_width + 1)
        porous[start:stop, :] = False
        porous[:, start:stop] = False
    return solid, porous


def solve_diffusion(
    tissue_mask: np.ndarray,
    parameters: ModelParameters = ModelParameters(),
) -> tuple[np.ndarray, int, bool]:
    """Solve D∇²C-R=0 by Jacobi iteration with fixed C0 in non-tissue cells."""
    mask = np.asarray(tissue_mask, dtype=bool)
    if mask.ndim != 2 or min(mask.shape) < 3:
        raise ValueError("tissue_mask must be a 2D array at least 3x3")
    if mask.shape != (parameters.grid_size, parameters.grid_size):
        raise ValueError("tissue_mask shape must match the configured square grid_size")
    if (
        parameters.length_m <= 0
        or parameters.diffusion_m2_s <= 0
        or parameters.consumption_mol_m3_s < 0
        or parameters.boundary_concentration_mol_m3 < 0
        or parameters.tolerance <= 0
        or parameters.max_iterations < 1
    ):
        raise ValueError("Diffusion parameters and solver limits are outside valid ranges")

    dx = parameters.length_m / (parameters.grid_size - 1)
    alpha = parameters.consumption_mol_m3_s * dx**2 / parameters.diffusion_m2_s
    concentration = np.full(mask.shape, parameters.boundary_concentration_mol_m3)
    for iteration in range(1, parameters.max_iterations + 1):
        old = concentration.copy()
        up = np.vstack((old[:1, :], old[:-1, :]))
        down = np.vstack((old[1:, :], old[-1:, :]))
        left = np.hstack((old[:, :1], old[:, :-1]))
        right = np.hstack((old[:, 1:], old[:, -1:]))
        updated = np.maximum((up + down + left + right - alpha) * 0.25, 0.0)
        concentration[mask] = updated[mask]
        concentration[~mask] = parameters.boundary_concentration_mol_m3
        if iteration % 500 == 0 and np.max(np.abs(concentration - old)) < parameters.tolerance:
            return concentration, iteration, True
    return concentration, parameters.max_iterations, False


def analyze_results(
    concentration: np.ndarray,
    tissue_mask: np.ndarray,
    threshold: float,
) -> dict[str, float]:
    """Calculate tissue necrosis and viable tissue as a percentage of the grid."""
    tissue = np.asarray(tissue_mask, dtype=bool)
    if concentration.shape != tissue.shape or not tissue.any():
        raise ValueError("Concentration and non-empty tissue mask must have equal shapes")
    living = (concentration >= threshold) & tissue
    return {
        "necrosis_tissue_percent": float(100 * np.count_nonzero(~living & tissue) / tissue.sum()),
        "living_grid_percent": float(100 * living.sum() / tissue.size),
    }


def run_model(parameters: ModelParameters = ModelParameters()) -> dict[str, object]:
    solid_mask, porous_mask = create_masks(parameters.grid_size)
    solid, solid_iterations, solid_converged = solve_diffusion(solid_mask, parameters)
    porous, porous_iterations, porous_converged = solve_diffusion(porous_mask, parameters)
    solid_metrics = analyze_results(
        solid, solid_mask, parameters.hypoxia_threshold_mol_m3
    )
    porous_metrics = analyze_results(
        porous, porous_mask, parameters.hypoxia_threshold_mol_m3
    )
    return {
        "solid_mask": solid_mask,
        "porous_mask": porous_mask,
        "solid_concentration": solid,
        "porous_concentration": porous,
        "solid_iterations": solid_iterations,
        "porous_iterations": porous_iterations,
        "solid_converged": solid_converged,
        "porous_converged": porous_converged,
        "solid_metrics": solid_metrics,
        "porous_metrics": porous_metrics,
        "removed_tissue_percent": float(
            100 * (solid_mask.sum() - porous_mask.sum()) / solid_mask.sum()
        ),
    }


def run_mesh_study(
    resolutions: tuple[int, ...] = (100, 150, 200),
    parameters: ModelParameters = ModelParameters(),
) -> list[dict[str, float | int | bool]]:
    """Compare the same physical setup across progressively finer grids."""
    if len(resolutions) < 2 or len(set(resolutions)) != len(resolutions):
        raise ValueError("Mesh study requires at least two unique grid resolutions")
    if any(size < 5 for size in resolutions):
        raise ValueError("Mesh resolutions must be at least 5")

    results: list[dict[str, float | int | bool]] = []
    for grid_size in resolutions:
        current_parameters = replace(parameters, grid_size=grid_size)
        result = run_model(current_parameters)
        results.append(
            {
                "grid_size": grid_size,
                "dx_um": current_parameters.length_m / (grid_size - 1) * 1e6,
                "solid_necrosis_percent": result["solid_metrics"]["necrosis_tissue_percent"],
                "porous_necrosis_percent": result["porous_metrics"]["necrosis_tissue_percent"],
                "solid_viable_grid_percent": result["solid_metrics"]["living_grid_percent"],
                "porous_viable_grid_percent": result["porous_metrics"]["living_grid_percent"],
                "removed_tissue_percent": result["removed_tissue_percent"],
                "solid_converged": result["solid_converged"],
                "porous_converged": result["porous_converged"],
                "solid_iterations": result["solid_iterations"],
                "porous_iterations": result["porous_iterations"],
            }
        )
    return results


def optimize_channel_grid(
    grid_size: int = 150,
    channel_counts: tuple[int, ...] = (1, 2, 3, 4, 5),
    half_widths: tuple[int, ...] = (0, 1, 2, 3, 4, 5),
    parameters: ModelParameters = ModelParameters(),
) -> list[dict[str, float | int | bool]]:
    """Evaluate regular channel grids and rank them by viable tissue per area."""
    if grid_size != parameters.grid_size:
        raise ValueError("grid_size must match parameters.grid_size")
    if not channel_counts or not half_widths:
        raise ValueError("At least one channel count and width must be provided")
    if any(count < 0 for count in channel_counts) or any(width < 0 for width in half_widths):
        raise ValueError("Channel counts and half-widths must be nonnegative")

    designs: list[dict[str, float | int | bool]] = []
    for channel_count in channel_counts:
        for half_width in half_widths:
            solid_mask, channel_mask = create_masks(
                grid_size=grid_size,
                reference_channel_half_width=half_width,
                channel_count=channel_count,
            )
            concentration, iterations, converged = solve_diffusion(channel_mask, parameters)
            metrics = analyze_results(
                concentration,
                channel_mask,
                parameters.hypoxia_threshold_mol_m3,
            )
            designs.append(
                {
                    "channel_count": channel_count,
                    "half_width_pixels": half_width,
                    "channel_width_pixels": 2 * half_width + 1,
                    "tissue_area_percent": float(100 * channel_mask.sum() / solid_mask.size),
                    "removed_tissue_percent": float(
                        100 * (solid_mask.sum() - channel_mask.sum()) / solid_mask.sum()
                    ),
                    "necrosis_tissue_percent": metrics["necrosis_tissue_percent"],
                    "viable_grid_percent": metrics["living_grid_percent"],
                    "iterations": iterations,
                    "converged": converged,
                }
            )
    return sorted(
        designs,
        key=lambda design: (
            design["viable_grid_percent"],
            -design["necrosis_tissue_percent"],
        ),
        reverse=True,
    )


def save_figure(result: dict[str, object], output: Path, threshold: float, c0: float) -> None:
    figure, axes = plt.subplots(2, 2, figsize=(10, 8), constrained_layout=True)
    masks = (result["solid_mask"], result["porous_mask"])
    concentrations = (result["solid_concentration"], result["porous_concentration"])
    labels = ("Solid scaffold", "Scaffold with manual channels")
    metric_keys = ("solid_metrics", "porous_metrics")
    for column in range(2):
        axes[0, column].imshow(~masks[column], cmap="gray", origin="upper")
        axes[0, column].set_title(f"{labels[column]} — geometry")
        axes[0, column].axis("off")
        image = axes[1, column].contourf(
            concentrations[column], levels=20, cmap="viridis", vmin=0, vmax=c0
        )
        axes[1, column].contour(
            concentrations[column], levels=[threshold], colors="red", linewidths=1.5
        )
        metrics = result[metric_keys[column]]
        axes[1, column].set_title(
            f"Oxygen — tissue below threshold: {metrics['necrosis_tissue_percent']:.1f}%"
        )
        axes[1, column].axis("off")
        figure.colorbar(image, ax=axes[1, column], label="Oxygen concentration (mol/m³)")
    figure.savefig(output, dpi=160)
    plt.close(figure)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).resolve().parent / "scaffold_diffusion_results.png",
        help="Path for the generated concentration and geometry figure",
    )
    parser.add_argument(
        "--mesh-study",
        action="store_true",
        help="Compare results on 100x100, 150x150, and 200x200 grids",
    )
    parser.add_argument(
        "--optimize-channels",
        action="store_true",
        help="Rank regular channel grids by viable tissue per scaffold area",
    )
    args = parser.parse_args()
    try:
        parameters = ModelParameters()
        if args.mesh_study:
            print(
                "Grid  dx (um)  solid hypoxia (%)  channels hypoxia (%)  "
                "solid viable grid (%)  channels viable grid (%)  "
                "removed tissue (%)  converged"
            )
            study = run_mesh_study(parameters=parameters)
            for row in study:
                converged = row["solid_converged"] and row["porous_converged"]
                print(
                    f"{row['grid_size']:>3}²  {row['dx_um']:>7.2f}  "
                    f"{row['solid_necrosis_percent']:>16.1f}  "
                    f"{row['porous_necrosis_percent']:>20.1f}  "
                    f"{row['solid_viable_grid_percent']:>21.1f}  "
                    f"{row['porous_viable_grid_percent']:>24.1f}  "
                    f"{row['removed_tissue_percent']:>18.1f}  {converged}"
                )
            if not all(
                row["solid_converged"] and row["porous_converged"] for row in study
            ):
                parser.error("At least one mesh did not converge; results are incomplete")
            print(
                "\nChannel half-width is scaled with grid spacing to keep its "
                "physical width approximately constant."
            )
            return 0
        if args.optimize_channels:
            designs = optimize_channel_grid(parameters=parameters)
            solid_mask, _ = create_masks(parameters.grid_size)
            solid_concentration, _, solid_converged = solve_diffusion(
                solid_mask, parameters
            )
            if not solid_converged:
                parser.error("Solid-scaffold reference calculation did not converge")
            print(
                "Rank  lines/axis  width (px)  tissue area (%)  "
                "tissue hypoxia (%)  viable scaffold area (%)  converged"
            )
            for rank, design in enumerate(designs, start=1):
                print(
                    f"{rank:>4}  {design['channel_count']:>10}  "
                    f"{design['channel_width_pixels']:>9}  "
                    f"{design['tissue_area_percent']:>15.1f}  "
                    f"{design['necrosis_tissue_percent']:>18.1f}  "
                    f"{design['viable_grid_percent']:>22.1f}  "
                    f"{design['converged']}"
                )
            if not all(design["converged"] for design in designs):
                parser.error("At least one channel design did not converge")
            best = designs[0]
            print(
                "\nBest tested design by viable tissue per total scaffold area: "
                f"{best['channel_count']} channels per axis, "
                f"{best['channel_width_pixels']} pixels wide, "
                f"{best['viable_grid_percent']:.1f}% viable area."
            )
            print(
                "This is a grid search over the specified regular patterns, "
                "not proof of a globally optimal or experimentally validated design."
            )
            best_mask = create_masks(
                grid_size=parameters.grid_size,
                reference_channel_half_width=best["half_width_pixels"] // 2,
                channel_count=best["channel_count"],
            )[1]
            best_concentration, _, _ = solve_diffusion(best_mask, parameters)
            best_metrics = analyze_results(
                best_concentration,
                best_mask,
                parameters.hypoxia_threshold_mol_m3,
            )
            best_result = {
                "solid_mask": solid_mask,
                "porous_mask": best_mask,
                "solid_concentration": solid_concentration,
                "porous_concentration": best_concentration,
                "solid_metrics": analyze_results(
                    solid_concentration,
                    solid_mask,
                    parameters.hypoxia_threshold_mol_m3,
                ),
                "porous_metrics": best_metrics,
            }
            args.output.parent.mkdir(parents=True, exist_ok=True)
            save_figure(
                best_result,
                args.output,
                parameters.hypoxia_threshold_mol_m3,
                parameters.boundary_concentration_mol_m3,
            )
            print(f"Best-design comparison figure saved to {args.output}")
            return 0

        result = run_model(parameters)
        for label, key in (
            ("Solid scaffold", "solid_metrics"),
            ("Scaffold with channels", "porous_metrics"),
        ):
            metrics = result[key]
            print(
                f"{label}: {metrics['necrosis_tissue_percent']:.1f}% of tissue "
                f"below threshold; {metrics['living_grid_percent']:.1f}% of full grid viable"
            )
        print(f"Removed from original tissue area by channels: {result['removed_tissue_percent']:.1f}%")
        print(
            f"Jacobi iterations: solid={result['solid_iterations']} "
            f"(converged={result['solid_converged']}), channels="
            f"{result['porous_iterations']} (converged={result['porous_converged']})"
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        save_figure(
            result,
            args.output,
            parameters.hypoxia_threshold_mol_m3,
            parameters.boundary_concentration_mol_m3,
        )
        print(f"Figure saved to {args.output}")
        return 0
    except (OSError, ValueError) as exc:
        parser.error(str(exc))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
