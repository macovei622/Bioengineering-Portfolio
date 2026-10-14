function [pct_cycle, knee_flexion_deg, grf_BW] = knee_gait_data()
% KNEE_GAIT_DATA  Returns normative walking gait cycle data:
%   - knee flexion angle (degrees) vs % gait cycle
%   - vertical ground reaction force (as multiples of body weight) vs %
%     gait cycle
%
% These manually specified points approximate published normative gait
% curves. They are not subject-specific measurements or an OpenSim trial.
% The curve shapes are based on:
%   Winter, D.A. (2009). Biomechanics and Motor Control of Human
%   Movement, 4th ed. The arrays below are illustrative approximations.

    pct_cycle = 0:5:100;

    knee_flexion_deg = [ ...
        5, 10, 15, 18, 15, 10, 6, 3, 2, 5, ...    % 0-45% gait cycle
        10, 20, 35, 50, 60, 55, 40, 25, 12, 5, ... % 50-95% gait cycle
        5];                                           % 100% closes the cycle

    grf_BW = [ ...
        0, 0.6, 1.05, 1.15, 1.05, 0.85, 0.75, 0.78, 0.85, 1.0, ... % 0-45%
        1.15, 0.9, 0.3, 0, 0, 0, 0, 0, 0, 0, ...                   % 50-95%
        0];                                                           % 100%

    assert(numel(pct_cycle) == numel(knee_flexion_deg));
    assert(numel(pct_cycle) == numel(grf_BW));
end
