% Моделирование диффузии кислорода в 3D-скаффолде (2D срез)
% Уравнение реакции-диффузии (Метод конечных разностей)
clear; clc; close all;

%% 1. Параметры модели (Биофизика)
L = 2e-3;           % Размер скаффолда: 2 мм (в метрах)
N = 150;            % Сетка 150x150 пикселей
dx = L / (N-1);     % Шаг сетки (пространственное разрешение)

D = 2e-9;           % Коэффициент диффузии O2 в гидрогеле (м^2/с)
R_max = 2.5e-3;     % Скорость потребления O2 клетками (моль/м^3 * с)
C0 = 0.2;           % Концентрация O2 в питательной среде (моль/м^3)
C_crit = 0.02;      % Порог гибели клеток (гипоксия/некроз)

% Коэффициент для конечно-разностной схемы
alpha = (R_max * dx^2) / D;

%% 2. Создание геометрии (Маски скаффолдов)
% 1 - гидрогель с клетками, 0 - питательная среда (каналы/снаружи)

% Сценарий А: Сплошной скаффолд (только внешнее омывание)
mask_solid = ones(N, N);
mask_solid(1,:) = 0; mask_solid(end,:) = 0; % Среда сверху/снизу
mask_solid(:,1) = 0; mask_solid(:,end) = 0; % Среда слева/справа

% Сценарий Б: Оптимизированный скаффолд (сетка макроканалов)
mask_porous = mask_solid;
spacing = round(N/4); % Шаг между каналами
width = 3;            % Полуширина канала
for i = 1:3
    idx = i * spacing;
    mask_porous(idx-width:idx+width, :) = 0; % Горизонтальные поры
    mask_porous(:, idx-width:idx+width) = 0; % Вертикальные поры
end

%% 3. Функция векторного решателя PDE (Jacobi Iteration)
solve_diffusion = @(mask) run_fdm_solver(mask, N, C0, alpha);

fprintf('Решение уравнения реакции-диффузии для сплошного скаффолда...\n');
C_solid = solve_diffusion(mask_solid);

fprintf('Решение уравнения реакции-диффузии для пористого скаффолда...\n');
C_porous = solve_diffusion(mask_porous);

%% 4. Анализ результатов (процент некроза)
% Считаем, какой процент клеток (где mask == 1) получает меньше C_crit
necrosis_solid = sum(C_solid(mask_solid==1) < C_crit) / sum(mask_solid(:)==1) * 100;
necrosis_porous = sum(C_porous(mask_porous==1) < C_crit) / sum(mask_porous(:)==1) * 100;

fprintf('--- РЕЗУЛЬТАТЫ ---\n');
fprintf('Сплошной матрикс: %.1f%% ткани в зоне некроза.\n', necrosis_solid);
fprintf('Пористый матрикс: %.1f%% ткани в зоне некроза.\n', necrosis_porous);

% Считаем полезный объем (количество выживших клеток)
living_tissue_solid = sum(C_solid(:) >= C_crit & mask_solid(:) == 1);
living_tissue_porous = sum(C_porous(:) >= C_crit & mask_porous(:) == 1);

fprintf('Полезный объем ЖИВОЙ ткани (относительно полного куба):\n');
fprintf('Сплошной матрикс: %.1f%%\n', (living_tissue_solid / N^2) * 100);
fprintf('Пористый матрикс: %.1f%%\n', (living_tissue_porous / N^2) * 100);

%% 5. Визуализация (Графики для отчета)
figure('Color', 'w', 'Position', [100, 100, 900, 700], 'Name', 'Scaffold O2 Diffusion');
colormap(parula);

% Геометрия 1
subplot(2,2,1);
imagesc(1-mask_solid); axis image off; title('Сплошной скаффолд (Архитектура)');
% Распределение O2 1
subplot(2,2,3);
contourf(C_solid, 20, 'LineStyle', 'none'); axis image off; hold on;
% Рисуем красную линию границы некроза
contour(C_solid, [C_crit C_crit], 'r-', 'LineWidth', 2);
colorbar; title(sprintf('Распределение O2\nНекроз: %.1f%%', necrosis_solid));
caxis([0 C0]);

% Геометрия 2
subplot(2,2,2);
imagesc(1-mask_porous); axis image off; title('Оптимизированный (Архитектура)');
% Распределение O2 2
subplot(2,2,4);
contourf(C_porous, 20, 'LineStyle', 'none'); axis image off; hold on;
% Рисуем красную линию границы некроза
contour(C_porous, [C_crit C_crit], 'r-', 'LineWidth', 2);
colorbar; title(sprintf('Распределение O2\nНекроз: %.1f%%', necrosis_porous));
caxis([0 C0]);

annotation('textbox', [0.35, 0.01, 0.5, 0.05], 'String', 'Красная линия - граница некроза клеток', 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'r', 'FontWeight', 'bold');

%% Вспомогательная функция (Векторный решатель)
function C = run_fdm_solver(mask, N, C0, alpha)
    C = ones(N,N) * C0; % Начальное условие: всё залито кислородом
    tol = 1e-6;
    for iter = 1:20000
        C_old = C;
        % Вычисление средних значений по соседям (векторный сдвиг матриц)
        C_up = C([1, 1:N-1], :);
        C_down = C([2:N, N], :);
        C_left = C(:, [1, 1:N-1]);
        C_right = C(:, [2:N, N]);
        
        % Метод конечных разностей (Laplacian - Consumption)
        C_new = 0.25 * (C_up + C_down + C_left + C_right) - 0.25 * alpha;
        C_new(C_new < 0) = 0; % Концентрация не может быть отрицательной
        
        % Применяем граничные условия и маску (в каналах концентрация C0)
        C(mask==1) = C_new(mask==1);
        C(mask==0) = C0;
        
        % Проверка на сходимость (установившийся режим)
        if mod(iter, 500) == 0
            if max(abs(C - C_old), [], 'all') < tol
                break;
            end
        end
    end
end