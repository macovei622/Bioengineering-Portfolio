# Verification Report

## Scope

This report records software-level checks for the educational Python ports of
Projects 1 and 3. It is not clinical validation, experimental validation, a
system safety assessment, or proof of conformity with ISO 14971 or IEC 62304.

## Current automated evidence

At documentation baseline `be95405`, the combined focused test command was:

```bash
python3 -m pytest -q \
  Project_1_EMG_Processing/EMG.Classification/files/python/test_emg_pipeline.py \
  Project_3_Scaffold_Diffusion/python/test_scaffold_diffusion.py
```

**Observed result:** 16 tests passed.

The test files cover CSV chunk reading, preprocessing input validation,
window segmentation, feature layout, repetition-group splitting, exercise
selection, synthetic signal generation, streaming predictor behavior,
geometry masks, solver behavior, metric denominators, default reference
metrics, mesh-study output, and channel-grid ranking. See
[requirements-traceability.md](./requirements-traceability.md) for the
requirement-to-test mapping.

## Additional recorded checks

- The scaffold default run converged for the solid and channelized masks and
  reproduced the documented 150 × 150 values: 31.4% of solid tissue below
  threshold, 0.0% of channelized tissue below threshold, and 66.8% / 71.7%
  viable full-grid area.
- The mesh study converged at 100 × 100, 150 × 150, and 200 × 200. Solid-mask
  below-threshold tissue was 31.8%, 31.4%, and 31.0%, respectively; the
  channelized cases reported 0.0%.
- The bounded channel-grid search converged for all 30 tested regular
  geometries. Its best tested candidate was one one-pixel-wide line in each
  direction, with 96.0% viable full-grid area for the current parameters and
  150 × 150 mesh. This is not an experimentally validated or grid-independent
  physical optimum.
- The EMG pipeline was run on an exercise-1 prefix and a grouped-repetition
  evaluation was recorded in the project README. The input prefix, held-out
  groups, and model choice affect results; this is not a subject-independent
  validation.

## Not performed

- Independent review of requirements, test design, or numerical derivation.
- Coverage measurement, mutation testing, or a complete traceability audit.
- Cross-platform or supported-version qualification.
- Independent implementation comparison for the diffusion equation.
- Biological validation of oxygen-consumption, boundary, or hypoxia parameters.
- Subject-independent EMG validation, prospective study, or user study.
- Actuator, prosthesis, clinical workflow, usability, cybersecurity, or
  hardware-in-the-loop testing.
- Formal residual-risk review or release approval by a quality organization.

## Reproduction

Run the tests from the repository root with:

```bash
python3 -m pytest -q \
  Project_1_EMG_Processing/EMG.Classification/files/python/test_emg_pipeline.py \
  Project_3_Scaffold_Diffusion/python/test_scaffold_diffusion.py
```

The test result must be regenerated for the current revision; the baseline
result above is historical evidence and does not certify later changes.
