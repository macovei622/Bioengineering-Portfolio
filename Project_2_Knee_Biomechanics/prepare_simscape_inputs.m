%% PREPARE_SIMSCAPE_INPUTS
% Turns the discrete gait-cycle data (21 points, every 5%) into smooth
% time-based signals you can feed into "From Workspace" blocks in your
% Simscape Multibody model.
%
% Run this BEFORE opening/running your Simulink model. It creates two
% variables in your base workspace:
%   knee_angle_input  - Simulink.SimulationData.Dataset-compatible
%                        [time, value] matrix, angle in RADIANS (Simscape
%                        Revolute Joint expects radians, not degrees!)
%   grf_input         - [time, value] matrix, vertical force in NEWTONS

clear knee_angle_input grf_input;

[pct_cycle, knee_flexion_deg, grf_BW] = knee_gait_data();

%% --- Time settings ---
gait_cycle_duration = 1.1;   % seconds for one full gait cycle (~1.1 s is
                              % typical for normal walking speed)
body_mass = 70;               % kg - EDIT to whatever subject mass you
                               % want to defend (70 kg is a common
                               % textbook reference value)
g = 9.81;                     % m/s^2
body_weight_N = body_mass * g;

time = (pct_cycle / 100) * gait_cycle_duration;

%% --- Interpolate to a finer time resolution for smooth simulation ---
dt = 0.001; % 1 ms simulation resolution
time_fine = 0:dt:gait_cycle_duration;

knee_angle_deg_fine = interp1(time, knee_flexion_deg, time_fine, 'pchip');
knee_angle_rad_fine = deg2rad(knee_angle_deg_fine);

grf_BW_fine = interp1(time, grf_BW, time_fine, 'pchip');
grf_BW_fine(grf_BW_fine < 0) = 0; % force can't be negative (no "pulling" from ground)
grf_N_fine = grf_BW_fine * body_weight_N;

%% --- Build [time, value] matrices for From Workspace blocks ---
knee_angle_input = [time_fine', knee_angle_rad_fine'];
grf_input = [time_fine', grf_N_fine'];

fprintf('knee_angle_input and grf_input are ready in the workspace.\n');
fprintf('Gait cycle duration: %.2f s, body weight: %.1f N\n', ...
    gait_cycle_duration, body_weight_N);

%% --- Quick sanity check plot before you even open Simulink ---
figure('Name', 'Gait input sanity check');
subplot(2,1,1);
plot(time_fine, knee_angle_deg_fine, 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Knee flexion (deg)');
title('Input to Revolute Joint (Provided by Input)');
grid on;

subplot(2,1,2);
plot(time_fine, grf_BW_fine, 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Vertical GRF (x Body Weight)');
title('Input to External Force on Tibia');
grid on;
