function feat_vec = extract_features(window, zc_threshold)
% EXTRACT_FEATURES  Computes the 4 classic time-domain EMG features
% (MAV, RMS, WL, ZC) for every channel in one window, and concatenates
% them into a single feature vector. Matches exactly the formulas we
% discussed - be ready to derive these from memory, not just cite them.
%
% Input:
%   window       - [win_len x N_channels] one segmented window
%   zc_threshold - noise threshold epsilon for zero-crossing counting
%                  (try 0.01 * max(abs(window(:))) as a starting point)
% Output:
%   feat_vec - [1 x (4*N_channels)] row vector:
%              [MAV_ch1 RMS_ch1 WL_ch1 ZC_ch1  MAV_ch2 RMS_ch2 ... ]

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

        % --- Zero Crossing rate (with noise threshold) ---
        zc = 0;
        for i = 1:n_samples-1
            if sign(x(i)) * sign(x(i+1)) == -1 && abs(x(i) - x(i+1)) > zc_threshold
                zc = zc + 1;
            end
        end

        base = (ch-1)*4;
        feat_vec(base+1) = mav;
        feat_vec(base+2) = rms_val;
        feat_vec(base+3) = wl;
        feat_vec(base+4) = zc;
    end
end
