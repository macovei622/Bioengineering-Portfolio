function gesture_smoothed = simulink_function_block(emg_sample)
%#codegen
% PASTE THIS INSIDE A "MATLAB Function" BLOCK IN SIMULINK.
%
% This block is called once per simulation time step with ONE new
% multichannel EMG sample (a row vector [1 x N_channels]). It buffers
% samples internally, and once it has a full 200 ms window, it computes
% features, classifies the gesture, and applies majority-vote smoothing
% over the last 5 predictions to avoid flicker.
%
% BEFORE USING: 
%  1) Run main_train_pipeline.m first so trained_emg_model.mat exists.
%  2) In the block's dialog, set this as a MATLAB Function block, and
%     load the model via coder.extrinsic or by converting mu/sigma/
%     coefficients to persistent constants (codegen cannot load .mat
%     files directly at runtime - see note at bottom).
%  3) Set the block's sample time to match your EMG sample rate (e.g.
%     1/2000 s if fs = 2000 Hz).

    persistent buffer buf_idx history model_mu model_sigma zc_thr fs_local model

    n_channels = numel(emg_sample);
    win_len = round(0.2 * 2000);   % 200 ms at fs = 2000 Hz - EDIT if your fs differs

    if isempty(buffer)
        buffer = zeros(win_len, n_channels);
        buf_idx = 0;
        history = zeros(1, 5); % last 5 predictions for majority vote

        % --- Load trained model params (extrinsic call, Simulink-only) ---
        coder.extrinsic('load');
        S = load('trained_emg_model.mat');
        model = S.chosen_model;      %#ok<NASGU>
        model_mu = S.mu;
        model_sigma = S.sigma;
        zc_thr = S.zc_threshold;
        fs_local = S.fs; %#ok<NASGU>
    end

    % --- Shift buffer and insert new sample ---
    buffer = [buffer(2:end, :); emg_sample];
    buf_idx = buf_idx + 1;

    gesture_smoothed = history(end); % hold last stable value by default

    if buf_idx >= win_len
        % --- Extract features on the current full window ---
        feat = extract_features(buffer, zc_thr);
        feat = (feat - model_mu) ./ model_sigma;

        % --- Predict (extrinsic call since predict() isn't codegen-native
        %     for all classifier types) ---
        coder.extrinsic('predict');
        raw_pred = 0;
        raw_pred = predict(model, feat); %#ok<NASGU>

        % --- Majority vote smoothing over last 5 predictions ---
        history = [history(2:end), raw_pred];
        gesture_smoothed = mode(history);
    end
end

% IMPLEMENTATION NOTE FOR YOUR DEFENSE:
% Loading a .mat file and calling predict() inside a MATLAB Function
% block only works in NORMAL SIMULATION mode (via coder.extrinsic),
% not if you later generate embedded C code for a real microcontroller.
% For a real embedded prosthetic controller, LDA is preferred over SVM
% precisely because its "predict" step is just a matrix multiply +
% argmax, which you would hand-code directly (no toolbox dependency) -
% this is the argument the earlier project notes told you to make, and
% now you can see concretely WHY it matters.
