import numpy as np
import pandas as pd
import pytest

from emg_pipeline import (
    ConcatenatedBinaryReader,
    EMGGesturePredictor,
    extract_features,
    generate_synthetic_emg,
    grouped_holdout,
    preprocess_emg,
    read_ninapro_csv,
    select_exercise,
    segment_windows,
)


def test_preprocess_validates_db1_envelope_without_filtering():
    signal = np.arange(40, dtype=float).reshape(4, 10)
    assert np.array_equal(preprocess_emg(signal), signal)
    with pytest.raises(ValueError, match="100 Hz"):
        preprocess_emg(signal, fs=2000)


def test_segment_windows_discards_group_crossings_and_impure_labels():
    emg = np.arange(600, dtype=float).reshape(60, 10)
    labels = np.zeros(60, dtype=int)
    labels[5:8] = 1
    groups = np.repeat([0, 1, 2], 20)
    windows, window_labels, window_groups = segment_windows(emg, labels, groups)
    assert windows.shape[1:] == (20, 10)
    assert len(windows) == len(window_labels) == len(window_groups) == 2
    assert np.array_equal(window_groups, [1, 2])
    assert np.array_equal(window_labels, [0, 0])


def test_features_follow_channel_major_matlab_layout():
    window = np.tile(np.arange(20, dtype=float)[:, None], (1, 10))
    features = extract_features(window, slope_threshold=0.5)
    assert features.shape == (1, 40)
    assert np.allclose(features[0, :4], [9.5, np.sqrt(np.mean(np.arange(20) ** 2)), 19, 0])
    for channel in range(10):
        assert np.allclose(features[0, channel * 4 : (channel + 1) * 4], features[0, :4])


def test_grouped_holdout_never_splits_groups_and_retains_all_classes():
    groups = np.repeat(np.arange(10), 4)
    labels = np.tile([0, 1, 0, 1], 10)
    train, test = grouped_holdout(labels, groups)
    assert set(groups[train]).isdisjoint(groups[test])
    assert np.array_equal(np.unique(labels[train]), [0, 1])
    assert np.array_equal(np.unique(labels[test]), [0, 1])


def test_select_exercise_prevents_mixing_gesture_numbering():
    frame = pd.DataFrame(
        {
            "exercise": [1, 1, 2, 2],
            "restimulus": [0, 12, 0, 23],
            "subject": [10, 10, 10, 10],
            "repetition": [0, 1, 0, 1],
        }
    )
    selected = select_exercise(frame, 1)
    assert selected["exercise"].tolist() == [1, 1]
    assert selected["restimulus"].tolist() == [0, 12]
    assert select_exercise(frame, 2)["restimulus"].tolist() == [0, 23]
    with pytest.raises(ValueError, match="No samples"):
        select_exercise(frame, 3)
    frame.loc[frame["exercise"] == 1, "restimulus"] = 23
    with pytest.raises(ValueError, match="0-12"):
        select_exercise(frame, 1)


def test_csv_reader_joins_parts_even_when_a_record_is_split(tmp_path):
    columns = [
        *(f"emg_{i}" for i in range(10)),
        "restimulus",
        "subject",
        "exercise",
        "repetition",
    ]
    rows = [[0.1] * 10 + [1, 2, 3, 4], [0.2] * 10 + [0, 2, 3, 5]]
    csv_bytes = pd.DataFrame(rows, columns=columns).to_csv(index=False).encode()
    (tmp_path / "Ninapro_DB1.csv.part00").write_bytes(csv_bytes[:31])
    (tmp_path / "Ninapro_DB1.csv.part01").write_bytes(csv_bytes[31:])

    frame = read_ninapro_csv(tmp_path, max_samples=2)
    assert frame.shape == (2, 14)
    assert frame["restimulus"].tolist() == [1, 0]


def test_concatenated_reader_closes_current_chunk(tmp_path):
    part = tmp_path / "part"
    part.write_bytes(b"abc")
    reader = ConcatenatedBinaryReader([part])
    assert reader.read(3) == b"abc"
    reader.close()
    assert reader.closed


def test_synthetic_generator_is_reproducible_and_separate_from_db1():
    emg, labels, fs = generate_synthetic_emg()
    assert fs == 2_000
    assert emg.shape == (420_000, 10)
    assert labels.shape == (420_000,)
    assert np.array_equal(np.unique(labels), np.arange(5))
    repeated_emg, repeated_labels, repeated_fs = generate_synthetic_emg()
    assert repeated_fs == fs
    assert np.array_equal(emg[:10], repeated_emg[:10])
    assert np.array_equal(labels, repeated_labels)


def test_streaming_predictor_defaults_to_the_improved_classifier():
    class ConstantClassifier:
        def predict(self, features):
            assert features.shape == (1, 40)
            return np.array([3])

    predictor = EMGGesturePredictor(
        {
            "models": {"extra_trees": ConstantClassifier()},
            "feature_mean": np.zeros(40),
            "feature_scale": np.ones(40),
            "slope_threshold": 0.01,
            "channel_count": 10,
        }
    )
    predictions = [predictor.update(np.ones(10)) for _ in range(20)]
    assert predictor.classifier == "extra_trees"
    assert predictions[-1] == 3
    assert all(value is None for value in predictions[:-1])
