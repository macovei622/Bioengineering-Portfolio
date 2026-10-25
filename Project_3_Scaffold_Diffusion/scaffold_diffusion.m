% 2D oxygen diffusion model in a scaffold cross-section.
% Reaction-diffusion equation solved with the finite difference method.
clear; clc; close all;

%% 1. Model parameters (biophysics)
L = 2e-3;           % Scaffold size: 2 mm (in meters)
N = 150;            % Grid: 150x150 pixels
dx = L / (N-1);     % Grid spacing (spatial resolution)

D = 2e-9;           % O2 diffusion coefficient in hydrogel (m^2/s)
R_max = 2.5e-3;     % Cellular O2 consumption rate (mol/m^3 * s)
C0 = 0.2;           % O2 concentration in culture medium (mol/m^3)
C_crit = 0.02;      % Cell-death threshold (hypoxia/necrosis)

% Coefficient for the finite difference scheme.
alpha = (R_max * dx^2) / D;

%% 2. Create scaffold geometries (masks)
% 1 = cell-bearing hydrogel; 0 = culture medium (channels/outside).

% Scenario A: solid scaffold (oxygen supplied only at the outer boundary).
mask_solid = ones(N, N);
mask_solid(1,:) = 0; mask_solid(end,:) = 0; % Medium at top and bottom.
mask_solid(:,1) = 0; mask_solid(:,end) = 0; % Medium at left and right.

% Scenario B: scaffold with a manually specified regular channel grid.
mask_porous = mask_solid;
spacing = round(N/4); % Spacing between channels.
width = 3;            % Channel half-width.
for i = 1:3
    idx = i * spacing;
    mask_porous(idx-width:idx+width, :) = 0; % Horizontal channels.
    mask_porous(:, idx-width:idx+width) = 0; % Vertical channels.
end

%% 3. Vectorized PDE solver (Jacobi iteration)
solve_diffusion = @(mask) run_fdm_solver(mask, N, C0, alpha);

fprintf('Solving the reaction-diffusion equation for the solid scaffold...\n');
C_solid = solve_diffusion(mask_solid);

fprintf('Solving the reaction-diffusion equation for the channelized scaffold...\n');
C_porous = solve_diffusion(mask_porous);

%% 4. Analyze results (percentage of tissue below the threshold)
% Calculate the percentage of tissue pixels (mask == 1) below C_crit.
necrosis_solid = sum(C_solid(mask_solid==1) < C_crit) / sum(mask_solid(:)==1) * 100;
necrosis_porous = sum(C_porous(mask_porous==1) < C_crit) / sum(mask_porous(:)==1) * 100;

fprintf('--- RESULTS ---\n');
fprintf('Solid scaffold: %.1f%% of tissue below the threshold.\n', necrosis_solid);
fprintf('Channelized scaffold: %.1f%% of tissue below the threshold.\n', necrosis_porous);

% Count viable tissue pixels.
living_tissue_solid = sum(C_solid(:) >= C_crit & mask_solid(:) == 1);
living_tissue_porous = sum(C_porous(:) >= C_crit & mask_porous(:) == 1);

fprintf('Viable tissue as a fraction of the full grid:\n');
fprintf('Solid mask: %.1f%%\n', (living_tissue_solid / N^2) * 100);
fprintf('Channelized mask: %.1f%%\n', (living_tissue_porous / N^2) * 100);
fprintf('Original tissue area removed by channels: %.1f%%\n', ...
    (sum(mask_solid(:)) - sum(mask_porous(:))) / sum(mask_solid(:)) * 100);

%% 5. Visualization (report figures)
figure('Color', 'w', 'Position', [100, 100, 900, 700], 'Name', 'Scaffold O2 Diffusion');
colormap(parula);

% Geometry 1.
subplot(2,2,1);
imagesc(1-mask_solid); axis image off; title('Solid scaffold (geometry)');
% Oxygen distribution 1.
subplot(2,2,3);
contourf(C_solid, 20, 'LineStyle', 'none'); axis image off; hold on;
% Draw the red line marking the threshold boundary.
contour(C_solid, [C_crit C_crit], 'r-', 'LineWidth', 2);
colorbar; title(sprintf('O2 distribution\nBelow threshold: %.1f%%', necrosis_solid));
caxis([0 C0]);

% Geometry 2.
subplot(2,2,2);
imagesc(1-mask_porous); axis image off; title('Manually specified channels');
% Oxygen distribution 2.
subplot(2,2,4);
contourf(C_porous, 20, 'LineStyle', 'none'); axis image off; hold on;
% Draw the red line marking the threshold boundary.
contour(C_porous, [C_crit C_crit], 'r-', 'LineWidth', 2);
colorbar; title(sprintf('O2 distribution\nBelow threshold: %.1f%%', necrosis_porous));
caxis([0 C0]);

annotation('textbox', [0.35, 0.01, 0.5, 0.05], 'String', 'Red line marks the oxygen threshold', 'EdgeColor', 'none', 'FontSize', 12, 'Color', 'r', 'FontWeight', 'bold');

%% Helper function (vectorized solver)
function C = run_fdm_solver(mask, N, C0, alpha)
    C = ones(N,N) * C0; % Initial guess: the full grid is oxygenated.
    tol = 1e-6;
    for iter = 1:20000
        C_old = C;
        % Calculate neighbor values using vectorized matrix shifts.
        C_up = C([1, 1:N-1], :);
        C_down = C([2:N, N], :);
        C_left = C(:, [1, 1:N-1]);
        C_right = C(:, [2:N, N]);
        
        % Finite difference update (Laplacian - consumption).
        C_new = 0.25 * (C_up + C_down + C_left + C_right) - 0.25 * alpha;
        C_new(C_new < 0) = 0; % Concentration cannot be negative.
        
        % Apply the boundary conditions and mask (channels remain at C0).
        C(mask==1) = C_new(mask==1);
        C(mask==0) = C0;
        
        % Check for convergence to steady state.
        if mod(iter, 500) == 0
            if max(abs(C - C_old), [], 'all') < tol
                break;
            end
        end
    end
end