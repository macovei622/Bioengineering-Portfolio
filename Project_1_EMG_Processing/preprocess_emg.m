function emg_clean = preprocess_emg(emg_raw, fs)
% PREPROCESS_EMG  Bandpass (20-450 Hz) + notch (50 Hz) filtering of a
% multichannel EMG signal, exactly matching the pipeline we discussed:
%   - Butterworth bandpass, order 4, 20-450 Hz
%     removes DC drift/motion artifact (<20 Hz) and high-frequency
%     electronics noise (>450 Hz)
%   - Notch filter at 50 Hz to remove mains interference
%     (use 60 Hz instead if your NinaPro subset was recorded in a
%     60 Hz-mains country - check the dataset documentation)
%
% Input:
%   emg_raw - [N_samples x N_channels] raw EMG
%   fs      - sampling frequency in Hz
% Output:
%   emg_clean - filtered EMG, same size as emg_raw

    % --- Bandpass filter (Butterworth, order 4) ---
    bp = designfilt('bandpassiir', ...
        'FilterOrder', 4, ...
        'HalfPowerFrequency1', 20, ...
        'HalfPowerFrequency2', 450, ...
        'SampleRate', fs);

    % --- Notch filter at 50 Hz (mains hum) ---
    notch = designfilt('bandstopiir', ...
        'FilterOrder', 2, ...
        'HalfPowerFrequency1', 48, ...
        'HalfPowerFrequency2', 52, ...
        'SampleRate', fs);

    n_channels = size(emg_raw, 2);
    emg_clean = zeros(size(emg_raw));

    for ch = 1:n_channels
        x = emg_raw(:, ch);
        x = filtfilt(bp, x);      % zero-phase bandpass
        x = filtfilt(notch, x);   % zero-phase notch
        emg_clean(:, ch) = x;
    end
end
