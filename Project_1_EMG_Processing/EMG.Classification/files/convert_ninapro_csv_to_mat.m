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

% Извлекаем 10 каналов ЭМГ (из колонок emg_0 ... emg_9)
emg = [data_table.emg_0, data_table.emg_1, data_table.emg_2, data_table.emg_3, ...
    data_table.emg_4, data_table.emg_5, data_table.emg_6, data_table.emg_7, ...
    data_table.emg_8, data_table.emg_9];

% Извлекаем метки жестов
restimulus = data_table.restimulus;

% Сохраняем в правильном формате базы NinaPro
save('S1_A1_E1.mat', 'emg', 'restimulus');

fprintf('Успех! Файл S1_A1_E1.mat создан и готов к использованию.\n');
