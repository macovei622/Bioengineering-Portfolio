%% INSPECT_NINAPRO_CSV
% Run this FIRST, before anything else. Kaggle re-uploads of NinaPro
% come in several different column layouts, so we need to see yours
% before writing the real converter. This only reads a small chunk of
% the 3.37 GB file, it will NOT try to load the whole thing into memory.

csv_path = 'Ninapro_DB1.csv';  % <-- EDIT: put your actual file name/path here

opts = detectImportOptions(csv_path);
fprintf('Detected %d columns:\n', numel(opts.VariableNames));
disp(opts.VariableNames');

% Read just the first 2000 rows to see actual values
opts.DataLines = [2, 2001]; % skip header, read 2000 data rows
sample = readtable(csv_path, opts);

fprintf('\nFirst 5 rows:\n');
disp(sample(1:5, :));

fprintf('\nUnique values in likely label columns (checking columns with "stim" or "label" or "class" in the name):\n');
for i = 1:numel(opts.VariableNames)
    name = lower(opts.VariableNames{i});
    if contains(name, 'stim') || contains(name, 'label') || contains(name, 'class') || contains(name, 'gesture')
        fprintf('  %s: %s\n', opts.VariableNames{i}, mat2str(unique(sample.(opts.VariableNames{i}))'));
    end
end

fprintf(['\n>>> COPY the printed column list above and send it back - ' ...
    'that is the only thing needed to finalize convert_ninapro_csv_to_mat.m\n']);
