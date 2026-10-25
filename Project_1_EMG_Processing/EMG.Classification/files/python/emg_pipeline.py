"""Python pipeline for RMS-processed NinaPro DB1 EMG gesture classification."""

from __future__ import annotations

import argparse
import io
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import BinaryIO, Iterable

import joblib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.discriminant_analysis import LinearDiscriminantAnalysis
from sklearn.ensemble import ExtraTreesClassifier
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    ConfusionMatrixDisplay,
    confusion_matrix,
)
from sklearn.multiclass import OneVsOneClassifier
from sklearn.svm import LinearSVC


FS = 100
CHANNEL_COLUMNS = [f"emg_{channel}" for channel in range(10)]
REQUIRED_COLUMNS = CHANNEL_COLUMNS + [
    "restimulus",
    "subject",
    "exercise",
    "repetition",
]


class ConcatenatedBinaryReader(io.RawIOBase):
    """Read ordered byte chunks as one stream, including split CSV records."""

    def __init__(self, paths: Iterable[Path]) -> None:
        super().__init__()
        self._paths = iter(paths)
        self._current: BinaryIO | None = None

    def readable(self) -> bool:
        return True

    def readinto(self, buffer: bytearray | memoryview) -> int:
        view = memoryview(buffer).cast("B")
        written = 0
        while written < len(view):
            if self._current is None:
                try:
                    self._current = next(self._paths).open("rb")
                except StopIteration:
                    break
            count = self._current.readinto(view[written:])
            if count:
                written += count
            else:
                self._current.close()
                self._current = None
        return written

    def close(self) -> None:
        if self._current is not None:
            self._current.close()
            self._current = None
        super().close()


def default_data_source(data_dir: Path) -> Path:
    csv_path = data_dir / "Ninapro_DB1.csv"
    if csv_path.is_file():
        return csv_path
    parts = sorted(data_dir.glob("Ninapro_DB1.csv.part*"))
    if parts:
        return data_dir
    raise FileNotFoundError(
        f"No Ninapro_DB1.csv or Ninapro_DB1.csv.part* files in {data_dir}"
    )


def _source_stream(source: Path) -> io.BufferedReader | BinaryIO:
    if source.is_dir():
        parts = sorted(source.glob("Ninapro_DB1.csv.part*"))
        if not parts:
            raise FileNotFoundError(f"No CSV parts found in {source}")
        return io.BufferedReader(ConcatenatedBinaryReader(parts))
    if not source.is_file():
        raise FileNotFoundError(f"EMG CSV source does not exist: {source}")
    return source.open("rb")


def read_ninapro_csv(source: Path, max_samples: int | None = 100_000) -> pd.DataFrame:
    """Read the required columns and an optional prefix without restoring CSV parts."""
    if max_samples is not None and max_samples < 1:
        raise ValueError("max_samples must be positive or None")
    with _source_stream(source) as stream:
        frame = pd.read_csv(
            stream,
            usecols=REQUIRED_COLUMNS,
            nrows=max_samples,
            engine="c",
        )
    missing = sorted(set(REQUIRED_COLUMNS) - set(frame.columns))
    if missing:
        raise ValueError(f"CSV is missing required columns: {', '.join(missing)}")
    if frame.empty:
        raise ValueError("The CSV contains no data rows")
    values = frame[REQUIRED_COLUMNS].to_numpy(dtype=np.float64)
    if not np.isfinite(values).all():
        raise ValueError("EMG, labels, and group metadata must all be finite")
    return frame


def trim_to_complete_group(frame: pd.DataFrame, sample_limit: int | None) -> pd.DataFrame:
    """Match the MATLAB pilot behavior by discarding a partial final repetition."""
    if sample_limit is None or len(frame) <= sample_limit:
        return frame
    groups = frame[["subject", "exercise", "repetition"]].to_numpy()
    if np.array_equal(groups[sample_limit - 1], groups[sample_limit]):
        changes = np.flatnonzero(np.any(groups[1:sample_limit] != groups[: sample_limit - 1], axis=1))
        if changes.size == 0:
            raise ValueError("Pilot limit ends before the first complete repetition group")
        frame = frame.iloc[: changes[-1] + 1]
    else:
        frame = frame.iloc[:sample_limit]
    return frame


def select_exercise(frame: pd.DataFrame, exercise: int) -> pd.DataFrame:
    """Keep one exercise so identically numbered gestures are not conflated."""
    selected = frame.loc[frame["exercise"] == exercise].copy()
    if selected.empty:
        raise ValueError(f"No samples found for exercise {exercise}")
    labels = selected["restimulus"].unique()
    if np.any(labels < 0) or (exercise == 1 and np.any(labels > 12)):
        raise ValueError(
            f"Exercise {exercise} contains gesture labels outside the expected 0-12 range"
        )
    return selected.reset_index(drop=True)


def preprocess_emg(emg: np.ndarray, fs: int = FS) -> np.ndarray:
    """Validate DB1 RMS envelopes; do not filter them as raw high-rate EMG."""
    signal = np.asarray(emg, dtype=np.float64)
    if fs != FS:
        raise ValueError("This preprocessing path requires RMS-processed DB1 at 100 Hz")
    if signal.ndim != 2 or signal.shape[1] != len(CHANNEL_COLUMNS):
        raise ValueError("EMG must be a samples-by-10-channels matrix")
    if not np.isfinite(signal).all():
        raise ValueError("EMG values must all be finite")
    return signal


def generate_synthetic_emg(seed: int = 42) -> tuple[np.ndarray, np.ndarray, int]:
    """Generate the standalone 2 kHz raw-EMG-shaped test signal from the MATLAB helper."""
    rng = np.random.default_rng(seed)
    fs = 2_000
    channels = np.arange(1, 11, dtype=np.float64)
    signal_parts: list[np.ndarray] = []
    label_parts: list[np.ndarray] = []
    n_rest = 3 * fs
    n_gesture = 5 * fs
    for _ in range(6):
        for gesture in range(5):
            signal_parts.append(0.02 * rng.standard_normal((n_rest, len(channels))))
            label_parts.append(np.zeros(n_rest, dtype=np.int64))
            if gesture == 0:
                continue
            time = np.arange(n_gesture) / fs
            envelope = 0.6 + 0.4 * np.sin(2 * np.pi * 0.5 * time)
            gain = 0.3 + 0.7 * np.abs(np.sin(channels + gesture))
            carrier = np.sin(
                2 * np.pi * (60 + gesture * 25) * time[:, None] + channels[None, :]
            )
            noise = 0.3 * rng.standard_normal((n_gesture, len(channels)))
            signal_parts.append(gain[None, :] * envelope[:, None] * carrier + noise)
            label_parts.append(np.full(n_gesture, gesture, dtype=np.int64))
    return np.concatenate(signal_parts), np.concatenate(label_parts), fs


def segment_windows(
    emg: np.ndarray,
    labels: np.ndarray,
    groups: np.ndarray,
    fs: int = FS,
    win_ms: int = 200,
    step_ms: int = 50,
    purity_threshold: float = 0.9,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Return retained windows, majority labels, and repetition group IDs."""
    signal = np.asarray(emg)
    labels = np.asarray(labels).reshape(-1)
    groups = np.asarray(groups).reshape(-1)
    if signal.ndim != 2 or len(signal) != len(labels) or len(labels) != len(groups):
        raise ValueError("EMG, labels, and groups must have matching sample counts")
    win_len = round(win_ms * fs / 1000)
    step_len = round(step_ms * fs / 1000)
    if fs <= 0 or win_len < 1 or step_len < 1:
        raise ValueError("Sampling rate and window/step lengths must be positive")
    if not 0 < purity_threshold <= 1:
        raise ValueError("purity_threshold must be in (0, 1]")

    windows: list[np.ndarray] = []
    window_labels: list[float] = []
    window_groups: list[int] = []
    for start in range(0, len(signal) - win_len + 1, step_len):
        end = start + win_len
        window_group = groups[start]
        if not np.all(groups[start:end] == window_group):
            continue
        values, counts = np.unique(labels[start:end], return_counts=True)
        majority = values[np.argmax(counts)]
        if counts.max() / win_len >= purity_threshold:
            windows.append(signal[start:end])
            window_labels.append(majority)
            window_groups.append(window_group)
    if not windows:
        raise ValueError("No windows passed the group-boundary and label-purity checks")
    return (
        np.stack(windows),
        np.asarray(window_labels),
        np.asarray(window_groups),
    )


def extract_features(windows: np.ndarray, slope_threshold: float) -> np.ndarray:
    """Compute per-channel MAV, RMS, waveform length, and slope sign changes."""
    data = np.asarray(windows, dtype=np.float64)
    if data.ndim == 2:
        data = data[np.newaxis, ...]
    if data.ndim != 3 or data.shape[1] < 3:
        raise ValueError("Windows must have shape (windows, samples, channels)")
    if not np.isfinite(data).all() or not np.isfinite(slope_threshold):
        raise ValueError("Feature inputs and slope threshold must be finite")
    slopes = np.diff(data, axis=1)
    ssc = np.sum(
        (slopes[:, :-1, :] * slopes[:, 1:, :] < 0)
        & (np.abs(slopes[:, :-1, :]) > slope_threshold)
        & (np.abs(slopes[:, 1:, :]) > slope_threshold),
        axis=1,
    )
    features = np.stack(
        [
            np.mean(np.abs(data), axis=1),
            np.sqrt(np.mean(data**2, axis=1)),
            np.sum(np.abs(slopes), axis=1),
            ssc,
        ],
        axis=2,
    )
    return features.reshape(data.shape[0], -1)


def grouped_holdout(
    labels: np.ndarray,
    groups: np.ndarray,
    test_fraction: float = 0.3,
    seed: int = 1,
) -> tuple[np.ndarray, np.ndarray]:
    """Split whole repetition groups, requiring every class in both partitions."""
    labels = np.asarray(labels).reshape(-1)
    groups = np.asarray(groups).reshape(-1)
    if len(labels) != len(groups) or not 0 < test_fraction < 1:
        raise ValueError("Labels/groups must match and test_fraction must be in (0, 1)")
    group_values = np.unique(groups)
    if len(group_values) < 2:
        raise ValueError("At least two independent repetition groups are required")
    classes = np.unique(labels)
    n_test = max(1, round(test_fraction * len(group_values)))
    rng = np.random.RandomState(seed)
    for _ in range(1000):
        test_groups = rng.permutation(group_values)[:n_test]
        is_test = np.isin(groups, test_groups)
        if np.array_equal(np.unique(labels[is_test]), classes) and np.array_equal(
            np.unique(labels[~is_test]), classes
        ):
            return np.flatnonzero(~is_test), np.flatnonzero(is_test)
    raise ValueError("Could not find a group holdout containing every class in both sets")


def train_pipeline(
    source: Path,
    output_dir: Path,
    max_samples: int | None = 100_000,
    seed: int = 1,
    exercise: int = 1,
) -> dict[str, object]:
    """Train gesture classifiers for one exercise and evaluate held-out repetitions."""
    frame = read_ninapro_csv(source, None if max_samples is None else max_samples + 1)
    frame = trim_to_complete_group(frame, max_samples)
    frame = select_exercise(frame, exercise)
    emg = preprocess_emg(frame[CHANNEL_COLUMNS].to_numpy())
    labels = frame["restimulus"].to_numpy()
    group_tuples = pd.MultiIndex.from_frame(frame[["subject", "exercise", "repetition"]])
    groups, _ = pd.factorize(group_tuples, sort=False)
    if (groups < 0).any():
        raise ValueError("Subject, exercise, and repetition metadata cannot be missing")

    windows, window_labels, window_groups = segment_windows(emg, labels, groups)
    train_idx, test_idx = grouped_holdout(window_labels, window_groups, seed=seed)
    slope_threshold = 0.01 * np.max(np.abs(windows[train_idx]))
    features = extract_features(windows, slope_threshold)
    x_train, x_test = features[train_idx], features[test_idx]
    y_train, y_test = window_labels[train_idx], window_labels[test_idx]

    mean = x_train.mean(axis=0)
    scale = x_train.std(axis=0) + np.finfo(np.float64).eps
    x_train = (x_train - mean) / scale
    x_test = (x_test - mean) / scale

    models = {
        # Shrinkage provides a stable covariance estimate for correlated features.
        "lda": LinearDiscriminantAnalysis(solver="lsqr", shrinkage="auto"),
        "svm": OneVsOneClassifier(
            LinearSVC(random_state=seed, dual="auto", max_iter=10_000)
        ),
        "extra_trees": ExtraTreesClassifier(
            n_estimators=200,
            class_weight="balanced",
            max_features="sqrt",
            min_samples_leaf=2,
            n_jobs=-1,
            random_state=seed,
        ),
    }
    predictions: dict[str, np.ndarray] = {}
    metrics: dict[str, dict[str, object]] = {}
    for name, model in models.items():
        model.fit(x_train, y_train)
        prediction = model.predict(x_test)
        predictions[name] = prediction
        metrics[name] = {
            "accuracy": float(accuracy_score(y_test, prediction)),
            "balanced_accuracy": float(balanced_accuracy_score(y_test, prediction)),
            "confusion_matrix": confusion_matrix(y_test, prediction).tolist(),
        }

    baseline = float(accuracy_score(y_test, np.full_like(y_test, pd.Series(y_train).mode()[0])))
    bundle = {
        "models": models,
        "feature_mean": mean,
        "feature_scale": scale,
        "slope_threshold": float(slope_threshold),
        "fs": FS,
        "channel_count": len(CHANNEL_COLUMNS),
        "metrics": metrics,
    }
    output_dir.mkdir(parents=True, exist_ok=True)
    joblib.dump(bundle, output_dir / "trained_emg_model.joblib", compress=3)
    for name, prediction in predictions.items():
        display = ConfusionMatrixDisplay.from_predictions(
            y_test, prediction, cmap="Blues", colorbar=False
        )
        display.ax_.set_title(
            f"{name.upper()} — accuracy {metrics[name]['accuracy']:.1%}, "
            f"balanced {metrics[name]['balanced_accuracy']:.1%}"
        )
        display.figure_.tight_layout()
        display.figure_.savefig(output_dir / f"emg-{name}-confusion-matrix.png", dpi=150)
        plt.close(display.figure_)

    return {
        "samples": len(frame),
        "channels": emg.shape[1],
        "exercise": exercise,
        "subjects": int(frame["subject"].nunique()),
        "classes": int(frame["restimulus"].nunique()),
        "windows": len(windows),
        "train_windows": len(train_idx),
        "test_windows": len(test_idx),
        "held_out_groups": int(len(np.unique(window_groups[test_idx]))),
        "majority_baseline": baseline,
        "metrics": metrics,
        "output_dir": output_dir,
    }


@dataclass
class EMGGesturePredictor:
    """Stateful 100 Hz predictor with 200 ms windows and five-result smoothing."""

    bundle: dict[str, object]
    classifier: str = "extra_trees"

    def __post_init__(self) -> None:
        if self.classifier not in self.bundle["models"]:
            raise ValueError(f"Unknown classifier: {self.classifier}")
        self.window: list[np.ndarray] = []
        self.predictions: list[float] = []
        self.samples_seen = 0

    def update(self, sample: np.ndarray) -> float | None:
        sample = np.asarray(sample, dtype=np.float64).reshape(-1)
        if sample.shape != (self.bundle["channel_count"],) or not np.isfinite(sample).all():
            raise ValueError("Each sample must contain 10 finite EMG channel values")
        self.window.append(sample)
        if len(self.window) > 20:
            self.window.pop(0)
        self.samples_seen += 1
        if len(self.window) < 20 or (self.samples_seen - 20) % 5:
            return None

        features = extract_features(
            np.stack(self.window), float(self.bundle["slope_threshold"])
        )
        features = (features - self.bundle["feature_mean"]) / self.bundle["feature_scale"]
        prediction = self.bundle["models"][self.classifier].predict(features)[0]
        self.predictions.append(prediction)
        self.predictions = self.predictions[-5:]
        values, counts = np.unique(self.predictions, return_counts=True)
        return values[np.argmax(counts)].item()


def _inspect(source: Path, sample_count: int) -> None:
    frame = read_ninapro_csv(source, sample_count)
    print(f"Read {len(frame)} rows and {len(frame.columns)} required columns")
    print(frame.head().to_string(index=False))
    print("\nGesture labels in sample:")
    print(frame["restimulus"].value_counts().sort_index().to_string())


def main(argv: list[str] | None = None) -> int:
    data_dir = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    inspect_parser = subparsers.add_parser("inspect", help="Inspect a bounded CSV sample")
    inspect_parser.add_argument("--data", type=Path, default=None)
    inspect_parser.add_argument("--rows", type=int, default=2_000)
    train_parser = subparsers.add_parser("train", help="Train and evaluate the classifiers")
    train_parser.add_argument("--data", type=Path, default=None)
    train_parser.add_argument("--output-dir", type=Path, default=data_dir / "python" / "outputs")
    train_parser.add_argument("--max-samples", type=int, default=100_000)
    train_parser.add_argument("--seed", type=int, default=1)
    train_parser.add_argument(
        "--exercise",
        type=int,
        default=1,
        help="Train on one exercise only (default: 1; gesture labels 0-12)",
    )
    args = parser.parse_args(argv)
    try:
        source = args.data or default_data_source(data_dir)
        if args.command == "inspect":
            _inspect(source, args.rows)
            return 0
        result = train_pipeline(
            source, args.output_dir, args.max_samples, args.seed, args.exercise
        )
        print(
            f"Exercise {result['exercise']}: loaded {result['samples']} samples from "
            f"{result['subjects']} subjects, {result['channels']} channels and "
            f"{result['classes']} gesture classes; "
            f"{result['windows']} windows ({result['train_windows']} train, "
            f"{result['test_windows']} test); held out "
            f"{result['held_out_groups']} repetition groups."
        )
        print(f"Majority-class baseline: {result['majority_baseline']:.1%}")
        for name, scores in result["metrics"].items():
            print(
                f"{name.upper()}: accuracy {scores['accuracy']:.1%}; "
                f"balanced accuracy {scores['balanced_accuracy']:.1%}"
            )
        print(f"Model and plots saved to {result['output_dir']}")
        return 0
    except (FileNotFoundError, ValueError, pd.errors.ParserError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
