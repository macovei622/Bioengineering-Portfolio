%% MAIN_TRAIN_PIPELINE
% End-to-end pipeline: load data -> preprocess -> window -> extract
% features -> train LDA and SVM -> compare -> save the better model
% for use in the Simulink MATLAB Function block.
%
% HOW TO SWITCH FROM SYNTHETIC TO REAL NINAPRO DATA:
%   1) Download NinaPro DB1 (or DB2) from http://ninapro.hevs.ch
%      (free registration required).
%   2) Their .mat files contain variables `emg` [N x 10] and
%      `restimulus` [N x 1] (gesture label per sample) and `fs`.
%   3) Replace the "Load data" section below with:
%        S = load('S1_A1_E1.mat');
%        emg_raw = S.emg;
%        labels  = S.restimulus;
%        fs      = 100;   % check the dataset readme for the real fs
%      and keep only 4-5 gestures as discussed (filter labels first).

clear; clc; close all;

%% 1) Load data (synthetic for now - swap for real NinaPro as noted above)
[emg_raw, labels, fs] = generate_synthetic_emg();
fprintf('Loaded signal: %d samples, %d channels, fs=%d Hz\n', ...
    size(emg_raw,1), size(emg_raw,2), fs);

%% 2) Preprocess: bandpass 20-450 Hz + 50 Hz notch
emg_clean = preprocess_emg(emg_raw, fs);

%% 3) Segment into 200 ms windows, 75% overlap (step = 50 ms)
win_ms = 200;
step_ms = 50;
[windows, window_labels] = segment_windows(emg_clean, labels, fs, win_ms, step_ms);
fprintf('Segmented into %d windows\n', numel(windows));

%% 4) Feature extraction (MAV, RMS, WL, ZC per channel)
n_windows = numel(windows);
n_channels = size(emg_clean, 2);
X = zeros(n_windows, 4 * n_channels);

zc_threshold = 0.01 * max(abs(emg_clean(:)));

for i = 1:n_windows
    X(i, :) = extract_features(windows{i}, zc_threshold);
end
Y = window_labels;

fprintf('Feature matrix: %d windows x %d features\n', size(X,1), size(X,2));

%% 5) Train/test split (stratified-ish: simple random split here)
rng(1);
n = size(X, 1);
idx = randperm(n);
split_point = round(0.7 * n);
train_idx = idx(1:split_point);
test_idx  = idx(split_point+1:end);

X_train = X(train_idx, :); Y_train = Y(train_idx);
X_test  = X(test_idx, :);  Y_test  = Y(test_idx);

% Standardize features (fit on train only, apply to both)
mu = mean(X_train, 1);
sigma = std(X_train, [], 1) + eps;
X_train = (X_train - mu) ./ sigma;
X_test  = (X_test  - mu) ./ sigma;

%% 6) Train LDA
lda_model = fitcdiscr(X_train, Y_train);
Y_pred_lda = predict(lda_model, X_test);
acc_lda = mean(Y_pred_lda == Y_test);
fprintf('LDA test accuracy: %.1f%%\n', acc_lda*100);

%% 7) Train SVM (linear, one-vs-one via fitcecoc)
svm_template = templateSVM('KernelFunction', 'linear');
svm_model = fitcecoc(X_train, Y_train, 'Learners', svm_template);
Y_pred_svm = predict(svm_model, X_test);
acc_svm = mean(Y_pred_svm == Y_test);
fprintf('SVM test accuracy: %.1f%%\n', acc_svm*100);

%% 8) Confusion matrices
figure('Name', 'LDA Confusion Matrix');
confusionchart(Y_test, Y_pred_lda);
title(sprintf('LDA (acc = %.1f%%)', acc_lda*100));

figure('Name', 'SVM Confusion Matrix');
confusionchart(Y_test, Y_pred_svm);
title(sprintf('SVM (acc = %.1f%%)', acc_svm*100));

%% 9) Save the chosen model + normalization stats for Simulink use
% We pick LDA by default per the defense argument discussed
% (lower compute cost -> realistic for embedded prosthetic controllers).
% Change to svm_model if you decide to defend SVM instead.
chosen_model = lda_model;
save('trained_emg_model.mat', 'chosen_model', 'mu', 'sigma', 'zc_threshold', 'fs');
fprintf('Saved trained_emg_model.mat\n');

fprintf(['\nNOTE: these numbers are from SYNTHETIC data - they only prove the ' ...
    'pipeline runs end-to-end. Re-run this exact script with real NinaPro ' ...
    'data before quoting any accuracy on your resume or in an interview.\n']);
