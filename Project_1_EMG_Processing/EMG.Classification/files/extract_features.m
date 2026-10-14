function feat_vec = extract_features(window, slope_threshold)
% Compute four time-domain features for each channel of an RMS envelope:
% mean absolute value, RMS, waveform length, and slope sign changes.
%
% Input:
%   window       - [win_len x N_channels] one segmented window
%   slope_threshold - minimum adjacent slope magnitude counted for SSC
% Output:
%   feat_vec - [1 x (4*N_channels)] row vector:
%              [MAV_ch1 RMS_ch1 WL_ch1 SSC_ch1 MAV_ch2 RMS_ch2 ... ]

    [n_samples, n_channels] = size(window);
    feat_vec = zeros(1, 4 * n_channels);

    for ch = 1:n_channels
        x = window(:, ch);

        % --- Mean Absolute Value ---
        mav = mean(abs(x));

        % --- Root Mean Square ---
        rms_val = sqrt(mean(x.^2));

        % --- Waveform Length ---
        wl = sum(abs(diff(x)));

        % Slope sign changes remain meaningful for nonnegative RMS envelopes.
        slopes = diff(x);
        ssc = sum(slopes(1:end-1) .* slopes(2:end) < 0 & ...
            abs(slopes(1:end-1)) > slope_threshold & ...
            abs(slopes(2:end)) > slope_threshold);

        base = (ch-1)*4;
        feat_vec(base+1) = mav;
        feat_vec(base+2) = rms_val;
        feat_vec(base+3) = wl;
        feat_vec(base+4) = ssc;
    end
end
