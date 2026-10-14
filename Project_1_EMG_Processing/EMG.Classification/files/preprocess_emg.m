function emg_clean = preprocess_emg(emg_raw, fs)
% NinaPro DB1 is recorded at 100 Hz after RMS filtering at the electrodes.
% Do not apply a raw-EMG band-pass or a 50 Hz notch to this envelope data.
if fs ~= 100
    error('preprocess_emg:UnsupportedSamplingRate', ...
        'This preprocessing path is for RMS-processed NinaPro DB1 at 100 Hz.');
end
if ~isnumeric(emg_raw) || ~ismatrix(emg_raw) || any(~isfinite(emg_raw(:)))
    error('preprocess_emg:InvalidSignal', ...
        'EMG input must be a finite numeric samples-by-channels matrix.');
end

emg_clean = emg_raw;
end
