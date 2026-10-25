# System Scope and Intended Use

## Project 1 — EMG gesture classification

### Intended educational use

The Python pipeline is intended to demonstrate processing of RMS-processed
NinaPro DB1 exercise-1 signals, extraction of window-level features, training
of classifiers, and evaluation on held-out repetition groups. A streaming
predictor is included as a software example.

The current default command processes a bounded prefix of the bundled CSV
parts, selects exercise 1, and reports offline metrics. The number of samples
remaining after exercise selection can be smaller than the input-prefix limit.
Evaluation splits hold out repetitions, not subjects. Reported results are not
evidence of generalization to unseen users.

### Inputs and outputs

- Inputs: 10 EMG channels, gesture labels, subject/exercise/repetition
  metadata, a nominal 100 Hz sampling rate, model configuration, and software
  dependencies.
- Outputs: window predictions, accuracy and balanced-accuracy metrics,
  confusion matrices, and a serialized scikit-learn model bundle.
- The bundled signals are RMS-processed envelope data. The DB1 preprocessing
  path validates the expected rate and does not apply raw-EMG filters.

### Boundary and exclusions

There is no connection from this repository's Python prediction function to a
prosthesis, actuator, stimulation unit, or patient. The MATLAB Function block
is a normal-simulation example and is not standalone embedded code generation.
No closed-loop safety function, alarm, sensor-fault monitor, patient-specific
calibration process, clinical workflow, cybersecurity assessment, or
human-factors validation is provided.

An incorrect gesture prediction is a model output error in the current
standalone prototype. It becomes a potential physical hazard only if a
separate system uses that output to command an actuator or otherwise affects a
person. That future integration is explicitly outside this software boundary
and requires a new system-level risk assessment.

## Project 3 — scaffold oxygen diffusion

### Intended educational use

The Python model compares a steady-state 2D reaction-diffusion field for
specified scaffold masks and parameters. Its optional mesh study checks
numerical sensitivity to grid resolution; its channel search ranks a limited
set of regular geometries using viable grid area.

### Inputs and outputs

- Inputs: grid and geometry settings, diffusion coefficient, zero-order
  consumption rate, fixed boundary concentration, hypoxia threshold, solver
  tolerance, and iteration limit.
- Outputs: calculated concentration arrays, threshold-based tissue
  percentages, convergence indicators, and plots.
- A value below the selected oxygen threshold is a computational indicator. It
  is not a measured cell-death outcome.

### Boundary and exclusions

The model is a 2D steady-state numerical prototype. Channel boundaries are
idealized oxygen reservoirs held at a fixed concentration. The model does not
represent flow, pressure drop, vessel development, endothelial tissue,
cell-growth or necrosis dynamics, mechanical integrity, manufacturing
constraints, or patient-specific data.

The geometry search is a bounded comparison of regular straight channels. It
does not establish a global optimum, a physical vessel diameter, or a
biologically validated design. Results must not be used as clinical guidance
or as a substitute for experimental validation.

## Users and operating environment

The intended users are students, educators, and researchers inspecting
reproducible computational examples. Supported execution has only been
verified in the repository's current Python environment; a complete
platform-qualification matrix has not been established.

## Foreseeable misuse

- Presenting a repetition-holdout EMG score as performance on new people.
- Connecting the EMG prediction to an actuator without an independent
  system-level design and safety assessment.
- Treating an oxygen-threshold map as observed necrosis or as a validated
  prediction of cell survival.
- Treating the highest-ranked channel pattern as a validated or globally
  optimal tissue-engineering design.
