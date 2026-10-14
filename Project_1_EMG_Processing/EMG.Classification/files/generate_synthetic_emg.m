function [emg, labels, fs] = generate_synthetic_emg()
% GENERATE_SYNTHETIC_EMG  Creates a fake multichannel EMG recording that
% mimics the structure of NinaPro DB1 (10 channels, several gestures,
% rest periods between them). This is ONLY for testing the pipeline
% end-to-end before you plug in real NinaPro data. Do not use results
% from synthetic data as "accuracy" claims anywhere - it is not real
% biosignal data, just a structurally similar stand-in.
%
% Outputs:
%   emg    - [N_samples x N_channels] double, synthetic EMG signal
%   labels - [N_samples x 1] double, gesture label at each sample
%            (0 = rest, 1..5 = gestures)
%   fs     - sampling frequency in Hz (NinaPro DB1 uses 100 Hz for the
%            Cybergrasp-based acquisition; DB2/DB3 use 2000 Hz Delsys.
%            We use 2000 Hz here since it is more realistic for the
%            20-450 Hz bandpass used later.)

    rng(42); % reproducibility while you are debugging the pipeline

    fs = 2000;                  % Hz
    n_channels = 10;
    n_gestures = 5;             % rest + 4 gestures (paper suggests 4-5)
    rep_duration = 5;           % seconds per gesture repetition
    rest_duration = 3;          % seconds of rest between gestures
    n_reps = 6;                 % repetitions per gesture (like NinaPro)

    emg = [];
    labels = [];

    for rep = 1:n_reps
        for g = 0:n_gestures-1
            % --- rest period ---
            n_rest = round(rest_duration * fs);
            rest_signal = 0.02 * randn(n_rest, n_channels); % baseline noise
            emg = [emg; rest_signal]; %#ok<AGROW>
            labels = [labels; zeros(n_rest, 1)]; %#ok<AGROW>

            if g == 0
                continue; % g==0 slot is just extra rest, skip "gesture 0"
            end

            % --- gesture period ---
            n_gest = round(rep_duration * fs);
            t = (0:n_gest-1)' / fs;

            % Each gesture activates a different subset/weighting of
            % channels with a distinct dominant frequency, roughly
            % mimicking different muscle recruitment patterns.
            base_freq = 60 + g * 25;              % Hz, fake "dominant" freq
            envelope = 0.6 + 0.4 * sin(2*pi*0.5*t); % slow amplitude modulation

            gesture_signal = zeros(n_gest, n_channels);
            for ch = 1:n_channels
                % channel-specific gain to fake spatial pattern per gesture
                gain = 0.3 + 0.7 * abs(sin(ch + g));
                carrier = sin(2*pi*base_freq*t + ch);
                noise = 0.3 * randn(n_gest, 1);
                gesture_signal(:, ch) = gain * envelope .* carrier + noise;
            end

            emg = [emg; gesture_signal]; %#ok<AGROW>
            labels = [labels; g * ones(n_gest, 1)]; %#ok<AGROW>
        end
    end
end
