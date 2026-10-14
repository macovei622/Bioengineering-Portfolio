%% Конвертер датасета из CSV в MAT
% Скрипт считывает данные из вашего CSV файла и сохраняет их в формате NinaPro (.mat)

fprintf('Загрузка CSV файла (это может занять некоторое время)... \n');

% Замените 'your_file_name.csv' на точное имя вашего CSV файла в папке
csv_filename = 'Ninapro_DB1.csv'; 

if ~isfile(csv_filename)
    restore_ninapro_csv();
end

% Читаем таблицу
data_table = readtable(csv_filename);
required_columns = {'emg_0', 'emg_1', 'emg_2', 'emg_3', 'emg_4', ...
    'emg_5', 'emg_6', 'emg_7', 'emg_8', 'emg_9', ...
    'restimulus', 'subject', 'exercise', 'repetition'};
missing_columns = required_columns(~ismember(required_columns, ...
    data_table.Properties.VariableNames));
if ~isempty(missing_columns)
    error('convert_ninapro_csv_to_mat:MissingColumns', ...
        'CSV is missing required columns: %s', strjoin(missing_columns, ', '));
end

% Извлекаем 10 каналов ЭМГ (из колонок emg_0 ... emg_9)
emg = [data_table.emg_0, data_table.emg_1, data_table.emg_2, data_table.emg_3, ...
    data_table.emg_4, data_table.emg_5, data_table.emg_6, data_table.emg_7, ...
    data_table.emg_8, data_table.emg_9];

% Извлекаем метки жестов
restimulus = data_table.restimulus;
subject = data_table.subject;
exercise = data_table.exercise;
repetition = data_table.repetition;
fs = 100;

% Keep trial metadata so train/test can be split by complete repetitions.
save('S1_A1_E1.mat', 'emg', 'restimulus', 'subject', ...
    'exercise', 'repetition', 'fs', '-v7.3');

fprintf('Успех! Файл S1_A1_E1.mat создан и готов к использованию.\n');
