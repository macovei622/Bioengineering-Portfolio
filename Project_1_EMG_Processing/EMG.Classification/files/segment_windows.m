function [windows, window_labels] = segment_windows(emg, labels, fs, win_ms, step_ms)
% SEGMENT_WINDOWS  Slices continuous EMG + labels into overlapping
% sliding windows, as discussed: 200 ms windows with 50-75% overlap.
%
% Inputs:
%   emg      - [N_samples x N_channels]
%   labels   - [N_samples x 1] gesture label per sample
%   fs       - sampling frequency (Hz)
%   win_ms   - window length in milliseconds (e.g. 200)
%   step_ms  - step between window starts in milliseconds (e.g. 50 = 75% overlap)
%
% Outputs:
%   windows       - {1 x N_windows} cell array, each cell is
%                   [win_len x N_channels] raw (unfiltered-by-this-fn) segment
%   window_labels - [N_windows x 1] majority label of each window
%                   (a window is only kept if >=90% of its samples share
%                   one label, to avoid ambiguous transition windows)

    win_len = round(win_ms/1000 * fs);
    step_len = round(step_ms/1000 * fs);
    n_samples = size(emg, 1);

    starts = 1:step_len:(n_samples - win_len + 1);
    windows = cell(1, numel(starts));
    window_labels = nan(numel(starts), 1);

    keep = false(numel(starts), 1);

    for i = 1:numel(starts)
        idx = starts(i):(starts(i) + win_len - 1);
        seg = emg(idx, :);
        seg_labels = labels(idx);

        [most_common, count] = mode(seg_labels);
        purity = count / numel(seg_labels);

        if purity >= 0.9
            windows{i} = seg;
            window_labels(i) = most_common;
            keep(i) = true;
        end
    end

    windows = windows(keep);
    window_labels = window_labels(keep);
end
