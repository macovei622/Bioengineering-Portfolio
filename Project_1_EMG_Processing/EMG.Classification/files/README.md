# EMG Gesture Classification

For the educational risk register, software requirements, verification
evidence, and lifecycle notes, see the
[software safety and lifecycle package](../../../docs/software-safety/README.md).

## Python implementation

The Python implementation is in [`python/`](./python/). It streams either
`Ninapro_DB1.csv` or the repository's ordered `.part*` files directly, so the
3.3 GB CSV does not need to be restored as a separate file. It reads the 10 EMG
channels and trial metadata, keeps complete repetition groups in the pilot
prefix, defaults to exercise 1 (gesture labels 0–12), extracts the same 200 ms
windows / 50 ms step and MAV, RMS, waveform length, and SSC features, then
evaluates repetition-group holdout LDA, linear SVM, and class-balanced Extra
Trees classifiers. Extra Trees is the default streaming model because it
performs better than the linear models on the current held-out repetitions.
The pipeline keeps exercises separate because NinaPro reuses gesture numbers
across exercises. LDA uses automatic covariance shrinkage for numerical
stability; the exact model implementation and metrics can differ from MATLAB's
`pseudoLinear` LDA.

From the repository root, install dependencies and run:

```bash
python3 -m pip install -r requirements-python.txt
python3 Project_1_EMG_Processing/EMG.Classification/files/python/emg_pipeline.py inspect
python3 Project_1_EMG_Processing/EMG.Classification/files/python/emg_pipeline.py train
python3 Project_1_EMG_Processing/EMG.Classification/files/python/emg_pipeline.py train --max-samples 1000000 --output-dir Project_1_EMG_Processing/EMG.Classification/files/python/outputs_ex1_1m_improved
```

The training command defaults to a contiguous prefix of at most 100,000
samples and saves a scikit-learn model bundle and three confusion-matrix plots
under `python/outputs/`. Use `--data PATH` to select a CSV file or a directory
containing the ordered CSV parts and `--max-samples N` to change the pilot
size (N must be positive). The 100,000-sample default keeps memory and runtime
bounded. `EMGGesturePredictor` provides a 100 Hz streaming inference
equivalent to the illustrative MATLAB Function block. The standalone
`generate_synthetic_emg()` helper also reproduces the MATLAB test-signal
generator at 2 kHz; it is not valid input to the DB1 100 Hz preprocessing
pipeline and must not be used to report recognition accuracy. The one-vs-one
linear SVM uses scikit-learn's `LinearSVC` internally so larger evaluations
remain practical; its scores can differ slightly from MATLAB's ECOC SVM and
the earlier kernel-based scikit-learn pilot.

By default the classifier uses only exercise 1. Change this with `--exercise N`
to train a separate model for a different exercise. Do not combine exercise
gesture IDs into one classifier unless they are remapped to exercise-specific
classes.

The earlier million-sample result that mixed exercises was invalid: the same
`restimulus` IDs were treated as equivalent across different exercises. It
should not be interpreted as an evaluation of the exercise-1 classifier. All
reported evaluation splits hold out complete repetitions, not entire subjects,
so they do not measure generalization to unseen people.

On the exercise-1 subset of the first million samples, class-balanced Extra
Trees was evaluated on three seeded grouped-repetition splits. Accuracy was
**75.6%**, **80.6%**, and **79.6%**; balanced accuracy was **71.4%**, **72.6%**,
and **77.1%**, respectively. On the original seed-1 split, this is an
improvement over linear SVM (**56.6%** accuracy, **49.5%** balanced accuracy)
and LDA (**46.3%**, **37.8%**). The split holds out full repetitions, but the
training and test sets can contain different repetitions from the same
subjects. These results do not establish performance on unseen subjects.

These Python scores are separate from the MATLAB pilot figures below; the
libraries and seeded group-split implementations differ.

Focused tests:

```bash
python3 -m pytest Project_1_EMG_Processing/EMG.Classification/files/python/test_emg_pipeline.py
```

The MATLAB files remain available as the original implementation.

## Overview

This MATLAB pipeline uses RMS-processed NinaPro DB1 signals (10 channels,
100 Hz). It extracts window-level features and compares LDA and linear SVM
classifiers.

The DB1 electrodes apply RMS processing before recording. The pipeline does
not apply a raw-EMG 20–450 Hz band-pass or a 50 Hz notch filter.

## Files

- `main_train_pipeline.m` loads the converted dataset, creates a
  repetition-group holdout, trains classifiers, reports accuracy and
  balanced accuracy, and saves the LDA model.
- `convert_ninapro_csv_to_mat.m` converts the CSV and exports signal,
  labels, sampling rate, and repetition metadata.
- `restore_ninapro_csv.m` reconstructs the CSV from the repository's
  Git-LFS chunks when needed.
- `segment_windows.m` creates 200 ms windows at 50 ms steps and discards
  windows that cross repetition boundaries.
- `extract_features.m` computes MAV, RMS, waveform length, and slope sign
  changes (SSC) for each channel.
- `preprocess_emg.m` validates the DB1 sampling rate and leaves the
  preprocessed envelope unchanged.
- `generate_synthetic_emg.m` is a separate synthetic-data generator and is
  not used by the main pipeline.
- `simulink_function_block.m` contains an example MATLAB Function block
  for 100 Hz input.

## Run

1. Open MATLAB in this folder.
2. Run `convert_ninapro_csv_to_mat.m` to create `S1_A1_E1.mat`.
3. Run `main_train_pipeline.m`.
4. Review the printed accuracy, balanced accuracy, majority-class baseline,
   and confusion matrices. The script saves `trained_emg_model.mat`.

The pipeline processes a contiguous prefix of up to 100,000 samples and
holds out complete subject/exercise/repetition groups. It excludes windows
that cross group boundaries. This avoids splitting overlapping windows
from the same repetition across train and test, but it is not a
subject-independent evaluation. The confusion matrices below are from the
pilot run described here.

Pilot run on 99,925 samples: LDA accuracy **74.4%** and balanced accuracy
**67.4%**; linear SVM accuracy **78.7%** and balanced accuracy **74.2%**.
The majority-class baseline was **27.0%**. The holdout contained three
subject/exercise/repetition groups, but all samples were from the same
subject, so these results do not measure generalization to unseen users.
The reported LDA run used MATLAB's `pseudoLinear` discriminant type to
handle a predictor with zero within-class variance.

### Pilot-run confusion matrices

![LDA confusion matrix: accuracy 74.4%, balanced accuracy 67.4%](../../images/emg-lda-confusion-matrix-grouped-holdout.png)

![SVM confusion matrix: accuracy 78.7%, balanced accuracy 74.2%](../../images/emg-svm-confusion-matrix-grouped-holdout.png)

The required MATLAB toolbox is Statistics and Machine Learning Toolbox
(`fitcdiscr`, `fitcecoc`, `confusionmat`, `confusionchart`).

## Limitations

- Results use only a pilot subset, not the complete NinaPro DB1 dataset.
- Grouped holdout is by repetition, not by subject.
- The 200 ms window and 50 ms step have not been selected through a
  systematic parameter study.
- Embedded inference performance has not been benchmarked on target
  hardware.
- The Simulink block is an example for normal simulation. Its use of
  `coder.extrinsic` and `load` does not provide standalone embedded code
  generation.
