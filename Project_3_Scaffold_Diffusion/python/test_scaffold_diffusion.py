import numpy as np
import pytest

from scaffold_diffusion import (
    ModelParameters,
    analyze_results,
    create_masks,
    optimize_channel_grid,
    run_model,
    run_mesh_study,
    solve_diffusion,
)


def test_masks_have_fixed_boundaries_and_manual_channel_lines():
    solid, porous = create_masks()
    assert solid.shape == porous.shape == (150, 150)
    assert not solid[0].any() and not solid[-1].any()
    assert not solid[:, 0].any() and not solid[:, -1].any()
    assert porous.sum() < solid.sum()
    assert not porous[34:41].any()
    assert not porous[:, 34:41].any()


def test_channel_width_scales_with_grid_resolution():
    _, porous_150 = create_masks(150)
    _, porous_200 = create_masks(200)
    assert porous_150.sum() / porous_150.size == pytest.approx(
        porous_200.sum() / porous_200.size, abs=0.02
    )


def test_zero_consumption_converges_to_boundary_concentration():
    parameters = ModelParameters(
        grid_size=20,
        consumption_mol_m3_s=0,
        max_iterations=2_000,
    )
    mask = np.ones((20, 20), dtype=bool)
    mask[[0, -1], :] = False
    mask[:, [0, -1]] = False
    concentration, iterations, converged = solve_diffusion(mask, parameters)
    assert converged
    assert iterations % 500 == 0
    assert np.allclose(concentration, parameters.boundary_concentration_mol_m3)


def test_analysis_reports_necrosis_over_tissue_and_viability_over_grid():
    mask = np.array([[False, False, False], [False, True, True], [False, False, False]])
    concentration = np.array([[1, 1, 1], [1, 0.01, 0.2], [1, 1, 1]])
    result = analyze_results(concentration, mask, threshold=0.02)
    assert result["necrosis_tissue_percent"] == 50
    assert result["living_grid_percent"] == pytest.approx(100 / 9)


def test_default_model_matches_documented_pilot_metrics():
    result = run_model()
    assert result["solid_converged"]
    assert result["porous_converged"]
    assert result["solid_metrics"]["necrosis_tissue_percent"] == pytest.approx(31.4, abs=0.1)
    assert result["porous_metrics"]["necrosis_tissue_percent"] == pytest.approx(0.0, abs=0.1)
    assert result["solid_metrics"]["living_grid_percent"] == pytest.approx(66.8, abs=0.1)
    assert result["porous_metrics"]["living_grid_percent"] == pytest.approx(71.7, abs=0.1)
    assert result["removed_tissue_percent"] == pytest.approx(26.4, abs=0.1)


def test_mesh_study_returns_convergence_and_resolution_metrics():
    parameters = ModelParameters(max_iterations=2_000, tolerance=1e-4)
    study = run_mesh_study((20, 25), parameters)
    assert [row["grid_size"] for row in study] == [20, 25]
    assert all(row["dx_um"] > 0 for row in study)
    assert all(isinstance(row["solid_converged"], bool) for row in study)
    assert all(0 <= row["solid_necrosis_percent"] <= 100 for row in study)


def test_channel_grid_optimizer_ranks_viable_area_and_keeps_design_metrics():
    parameters = ModelParameters(grid_size=20, max_iterations=2_000, tolerance=1e-4)
    designs = optimize_channel_grid(
        grid_size=20,
        channel_counts=(1, 2),
        half_widths=(0, 1),
        parameters=parameters,
    )
    assert len(designs) == 4
    assert designs[0]["viable_grid_percent"] >= designs[-1]["viable_grid_percent"]
    assert all(0 <= row["removed_tissue_percent"] <= 100 for row in designs)
    assert all(row["converged"] for row in designs)
