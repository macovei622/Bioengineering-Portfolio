%% MAIN_TRAIN_PIPELINE
% Loads RMS-processed NinaPro DB1 data, extracts window features, holds out
% complete subject/exercise/repetition groups, trains LDA and SVM, and
% reports accuracy and balanced accuracy.

clear; clc; close all;

%% 1) Load converted NinaPro DB1 data
S = load('S1_A1_E1.mat');
required_fields = {'emg', 'restimulus', 'subject', 'exercise', 'repetition', 'fs'};
missing_fields = required_fields(~isfield(S, required_fields));
if ~isempty(missing_fields)
    error('main_train_pipeline:MissingMetadata', ...
        ['S1_A1_E1.mat is missing %s. Re-run ' ...
        'convert_ninapro_csv_to_mat.m to export trial metadata.'], ...
        strjoin(missing_fields, ', '));
end

fs = S.fs;
if fs ~= 100
    error('main_train_pipeline:UnexpectedSamplingRate', ...
        'Expected RMS-processed NinaPro DB1 data sampled at 100 Hz.');
end
emg_raw = S.emg;
labels = S.restimulus(:);
groups = findgroups(S.subject(:), S.exercise(:), S.repetition(:));
if any(isnan(groups))
    error('main_train_pipeline:MissingGroupMetadata', ...
        'Subject, exercise, and repetition metadata must not contain missing values.');
end

% Use a contiguous pilot segment to keep this example practical to run.
n_samples = min(100000, size(emg_raw, 1));
if n_samples < size(emg_raw, 1) && groups(n_samples) == groups(n_samples + 1)
    last_complete_group_end = find( ...
        groups(1:n_samples-1) ~= groups(2:n_samples), 1, 'last');
    if isempty(last_complete_group_end)
        error('main_train_pipeline:NoCompletePilotGroups', ...
            'The pilot limit ends before the first complete repetition group.');
    end
    n_samples = last_complete_group_end;
end
emg_raw = emg_raw(1:n_samples, :);
labels = labels(1:n_samples);
groups = groups(1:n_samples);
fprintf('Loaded %d NinaPro DB1 samples, %d channels, fs=%d Hz\n', ...
    size(emg_raw, 1), size(emg_raw, 2), fs);

%% 2) Do not band-pass RMS-processed DB1 data a second time
emg_clean = preprocess_emg(emg_raw, fs);

%% 3) Segment into 200 ms windows with a 50 ms step
win_ms = 200;
step_ms = 50;
[windows, window_labels, window_groups] = ...
    segment_windows(emg_clean, labels, groups, fs, win_ms, step_ms);
fprintf('Segmented into %d windows\n', numel(windows));

%% 4) Feature extraction (MAV, RMS, WL, SSC per channel)
n_windows = numel(windows);
n_channels = size(emg_clean, 2);
X = zeros(n_windows, 4 * n_channels);
Y = window_labels;

%% 5) Hold out complete subject/exercise/repetition groups
[train_idx, test_idx] = grouped_holdout(Y, window_groups, 0.3, 1);
training_samples = vertcat(windows{train_idx});
slope_threshold = 0.01 * max(abs(training_samples(:)));

for i = 1:n_windows
    X(i, :) = extract_features(windows{i}, slope_threshold);
end

fprintf('Feature matrix: %d windows x %d features\n', size(X,1), size(X,2));

X_train = X(train_idx, :); Y_train = Y(train_idx);
X_test  = X(test_idx, :);  Y_test  = Y(test_idx);
fprintf('Train: %d windows; test: %d windows; held-out groups: %d\n', ...
    numel(train_idx), numel(test_idx), numel(unique(window_groups(test_idx))));
majority_class = mode(Y_train);
baseline_acc = mean(Y_test == majority_class);
fprintf('Majority-class baseline (class %g): %.1f%%\n', ...
    majority_class, baseline_acc * 100);

% Standardize features (fit on train only, apply to both)
mu = mean(X_train, 1);
sigma = std(X_train, [], 1) + eps;
X_train = (X_train - mu) ./ sigma;
X_test  = (X_test  - mu) ./ sigma;

%% 6) Train LDA
lda_model = fitcdiscr(X_train, Y_train);
Y_pred_lda = predict(lda_model, X_test);
acc_lda = mean(Y_pred_lda == Y_test);
balanced_acc_lda = mean_class_recall(Y_test, Y_pred_lda);
fprintf('LDA test accuracy: %.1f%%; balanced accuracy: %.1f%%\n', ...
    acc_lda*100, balanced_acc_lda*100);

%% 7) Train SVM (linear, one-vs-one via fitcecoc)
svm_template = templateSVM('KernelFunction', 'linear');
svm_model = fitcecoc(X_train, Y_train, 'Learners', svm_template);
Y_pred_svm = predict(svm_model, X_test);
acc_svm = mean(Y_pred_svm == Y_test);
balanced_acc_svm = mean_class_recall(Y_test, Y_pred_svm);
fprintf('SVM test accuracy: %.1f%%; balanced accuracy: %.1f%%\n', ...
    acc_svm*100, balanced_acc_svm*100);

%% 8) Confusion matrices
figure('Name', 'LDA Confusion Matrix');
confusionchart(Y_test, Y_pred_lda);
title(sprintf('LDA (acc = %.1f%%, balanced acc = %.1f%%)', ...
    acc_lda*100, balanced_acc_lda*100));

figure('Name', 'SVM Confusion Matrix');
confusionchart(Y_test, Y_pred_svm);
title(sprintf('SVM (acc = %.1f%%, balanced acc = %.1f%%)', ...
    acc_svm*100, balanced_acc_svm*100));

%% 9) Save the chosen model + normalization stats for Simulink use
% Keep LDA as the default embedded-model candidate; compare its metrics
% with SVM before making claims about deployment suitability.
chosen_model = lda_model;
save('trained_emg_model.mat', 'chosen_model', 'mu', 'sigma', ...
    'slope_threshold', 'fs', 'acc_lda', 'balanced_acc_lda', ...
    'acc_svm', 'balanced_acc_svm');
fprintf('Saved trained_emg_model.mat\n');

fprintf(['\nEvaluation uses a contiguous pilot prefix (up to 100,000 samples) and holds ' ...
    'out complete subject/exercise/repetition groups. Results are not a ' ...
    'subject-independent estimate unless subjects are held out explicitly.\n']);

function score = mean_class_recall(truth, prediction)
    classes = unique(truth);
    matrix = confusionmat(truth, prediction, 'Order', classes);
    score = mean(diag(matrix) ./ sum(matrix, 2));
end

function [train_idx, test_idx] = grouped_holdout(labels, groups, test_fraction, seed)
    if numel(labels) ~= numel(groups) || test_fraction <= 0 || test_fraction >= 1
        error('grouped_holdout:InvalidInput', ...
            'Labels and groups must have equal lengths and test_fraction must be between 0 and 1.');
    end

    group_values = unique(groups);
    if numel(group_values) < 2
        error('grouped_holdout:TooFewGroups', ...
            'At least two independent groups are required for a holdout split.');
    end

    rng(seed);
    n_test_groups = max(1, round(test_fraction * numel(group_values)));
    classes = unique(labels);
    for attempt = 1:1000
        order = randperm(numel(group_values));
        test_groups = group_values(order(1:n_test_groups));
        is_test = ismember(groups, test_groups);
        if all(ismember(classes, unique(labels(is_test)))) && ...
                all(ismember(classes, unique(labels(~is_test))))
            train_idx = find(~is_test);
            test_idx = find(is_test);
            return;
        end
    end

    error('grouped_holdout:ClassCoverageFailed', ...
        'Could not find a group holdout split containing every class in train and test.');
end
