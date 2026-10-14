function emg_clean = preprocess_emg(emg_raw, fs)
% Адаптированный фильтр под низкую частоту fs = 100 Гц

% Полосовой фильтр Баттерворта 4-го порядка (10–45 Гц)
bp = designfilt('bandpassiir', ...
    'FilterOrder', 4, ...
    'HalfPowerFrequency1', 10, ...
    'HalfPowerFrequency2', 45, ...
    'SampleRate', fs);

% Применяем фильтрацию ко всем каналам
emg_clean = filtfilt(bp, emg_raw);

% Режекторный (notch) фильтр на 50 Гц убираем, так как при fs=100 Гц 
% частота 50 Гц является максимальной границей и отфильтруется полосовым.
end
