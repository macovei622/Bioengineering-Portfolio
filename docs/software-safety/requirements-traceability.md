# Software Requirements and Traceability

## Requirement conventions

IDs are stable within this portfolio documentation. “Shall” statements are
software requirements for the educational prototypes only; they do not imply
medical-device suitability. Verification status is limited to the evidence
listed in the [verification report](./verification-report.md).

## Shared requirements

| ID | Requirement | Implementation | Verification | Risk links | Status |
|---|---|---|---|---|---|
| COM-01 | The software shall state its intended educational use and shall not represent prototype outputs as clinical or validated device outputs. | Project READMEs and [system scope](./system-scope.md) | Documentation review | R-01, R-05, R-06, R-07 | Documented; no external user-comprehension validation |
| COM-02 | Invalid or unsupported inputs shall produce an explicit error rather than a plausible success result. | `emg_pipeline.py`; `scaffold_diffusion.py` | Input-validation unit tests and CLI checks | R-03, R-08 | Partially verified by unit tests |

## Project 1 — EMG requirements

| ID | Requirement | Implementation | Verification | Risk links | Status |
|---|---|---|---|---|---|
| EMG-01 | The DB1 preprocessing path shall accept a finite samples-by-10-channels matrix at 100 Hz and shall not apply raw-EMG filtering. | `preprocess_emg()` in `Project_1_EMG_Processing/EMG.Classification/files/python/emg_pipeline.py` | `test_preprocess_validates_db1_envelope_without_filtering` | R-03 | Verified at function level |
| EMG-02 | CSV parts shall be read in sorted order as a continuous byte stream so records split across part boundaries can be parsed. | `ConcatenatedBinaryReader`; `read_ninapro_csv()` | `test_csv_reader_joins_parts_even_when_a_record_is_split`; `test_concatenated_reader_closes_current_chunk` | R-03, R-04 | Verified on synthetic split files; full production dataset integrity is not independently certified |
| EMG-03 | The default classifier workflow shall select one exercise and keep the gesture labels associated with that exercise. | `select_exercise()`; `train_pipeline()` | `test_select_exercise_prevents_mixing_gesture_numbering` | R-02, R-03 | Verified at function level |
| EMG-04 | Windows shall use the configured 200 ms length and 50 ms step, shall not cross repetition-group boundaries, and shall meet the label-purity threshold. | `segment_windows()` | `test_segment_windows_discards_group_crossings_and_impure_labels` | R-02 | Partially verified with a synthetic boundary case |
| EMG-05 | Each retained window shall produce per-channel MAV, RMS, waveform length, and slope-sign-change features in channel-major order. | `extract_features()` | `test_features_follow_channel_major_matlab_layout` | R-03 | Verified for a deterministic synthetic signal |
| EMG-06 | Train and test partitions shall contain disjoint repetition groups, and every evaluated class shall be represented in both partitions. | `grouped_holdout()` | `test_grouped_holdout_never_splits_groups_and_retains_all_classes` | R-02 | Verified on synthetic groups; subject-independent performance is not established |
| EMG-07 | Feature normalization parameters shall be fitted using training windows only and then applied unchanged to test windows. | `train_pipeline()` | Code inspection; not yet a dedicated unit test | R-02 | Implemented; dedicated automated test open |
| EMG-08 | Model evaluation shall report accuracy, balanced accuracy, a majority-class baseline, and confusion matrices. | `train_pipeline()` and CLI | Reproducible training run; output review | R-02 | Verified for recorded local run; not an independent replication |
| EMG-09 | The streaming example shall validate each sample, buffer 20 samples, update predictions every 5 samples, and smooth up to five predictions. | `EMGGesturePredictor` | `test_streaming_predictor_defaults_to_the_improved_classifier` | R-01, R-03 | Partially verified; fault/recovery and timing characteristics are not validated |
| EMG-10 | The serialized model bundle shall include models and the normalization/feature parameters required by the inference example. | `train_pipeline()` model bundle | Model reload and prediction smoke check | R-03, R-04 | Smoke-tested locally; artifact schema/versioning is not yet specified |

## Project 3 — scaffold requirements

| ID | Requirement | Implementation | Verification | Risk links | Status |
|---|---|---|---|---|---|
| SCF-01 | The model shall construct a solid mask and a channelized mask with specified outer boundaries and grid-scaled channel geometry. | `create_masks()` in `Project_3_Scaffold_Diffusion/python/scaffold_diffusion.py` | `test_masks_have_fixed_boundaries_and_manual_channel_lines`; `test_channel_width_scales_with_grid_resolution` | R-06, R-07 | Verified for tested grids; no physical geometry validation |
| SCF-02 | The solver shall use the documented zero-order finite-difference update, fixed-concentration non-tissue boundaries, and nonnegative concentration clipping. | `solve_diffusion()` | `test_zero_consumption_converges_to_boundary_concentration`; default reference test | R-05, R-06, R-08 | Partially verified; independent solver comparison open |
| SCF-03 | Solver output shall include iteration count and a convergence indicator. | `solve_diffusion()` and CLI | Default model test; CLI output review | R-08 | Verified for current test cases |
| SCF-04 | The model shall report below-threshold tissue percentage separately from viable percentage of the full grid. | `analyze_results()` | `test_analysis_reports_necrosis_over_tissue_and_viability_over_grid` | R-05 | Verified for a constructed mask |
| SCF-05 | Default parameters shall reproduce the documented 150 × 150 reference metrics within stated rounding tolerance. | `run_model()` | `test_default_model_matches_documented_pilot_metrics` | R-05, R-08 | Verified against implementation baseline; not against experiment |
| SCF-06 | The mesh study shall compare multiple resolutions and report convergence for each scenario. | `run_mesh_study()` and `--mesh-study` | `test_mesh_study_returns_convergence_and_resolution_metrics`; CLI run | R-08 | Verified for the listed resolutions; physical assumptions remain unvalidated |
| SCF-07 | Channel geometries shall be ranked by viable fraction of the full scaffold grid and also report tissue-area and hypoxia measures. | `optimize_channel_grid()` and `--optimize-channels` | `test_channel_grid_optimizer_ranks_viable_area_and_keeps_design_metrics`; CLI run | R-06, R-07 | Verified for the bounded candidate grid only |
