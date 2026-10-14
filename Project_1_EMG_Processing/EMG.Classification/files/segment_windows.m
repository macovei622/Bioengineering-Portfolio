function [windows, window_labels, window_groups] = ...
    segment_windows(emg, labels, groups, fs, win_ms, step_ms)
% Segment EMG into overlapping windows without crossing trial-group borders.
%
% Inputs:
%   emg      - [N_samples x N_channels]
%   labels   - [N_samples x 1] gesture label per sample
%   groups   - [N_samples x 1] independent subject/exercise/repetition IDs
%   fs       - sampling frequency (Hz)
%   win_ms   - window length in milliseconds (e.g. 200)
%   step_ms  - step between window starts in milliseconds (e.g. 50 = 75% overlap)
%
% Outputs:
%   windows       - {1 x N_windows} cell array, each cell is
%                   [win_len x N_channels] raw (unfiltered-by-this-fn) segment
%   window_labels - [N_windows x 1] majority label of each window
%   window_groups - [N_windows x 1] group ID for each retained window
% A window is kept only when it lies within one group and >=90% of its
% samples share one label.

    labels = labels(:);
    groups = groups(:);
    if size(emg, 1) ~= numel(labels) || numel(labels) ~= numel(groups)
        error('segment_windows:LengthMismatch', ...
            'EMG, labels, and groups must contain the same number of samples.');
    end

    win_len = round(win_ms/1000 * fs);
    step_len = round(step_ms/1000 * fs);
    n_samples = size(emg, 1);
    if win_len < 1 || step_len < 1
        error('segment_windows:InvalidWindow', ...
            'Window length and step must each correspond to at least one sample.');
    end

    starts = 1:step_len:(n_samples - win_len + 1);
    windows = cell(1, numel(starts));
    window_labels = nan(numel(starts), 1);
    window_groups = nan(numel(starts), 1);

    keep = false(numel(starts), 1);

    for i = 1:numel(starts)
        idx = starts(i):(starts(i) + win_len - 1);
        seg = emg(idx, :);
        seg_labels = labels(idx);

        [most_common, count] = mode(seg_labels);
        purity = count / numel(seg_labels);

        group_id = groups(idx(1));
        if purity >= 0.9 && all(groups(idx) == group_id)
            windows{i} = seg;
            window_labels(i) = most_common;
            window_groups(i) = group_id;
            keep(i) = true;
        end
    end

    windows = windows(keep);
    window_labels = window_labels(keep);
    window_groups = window_groups(keep);
end
