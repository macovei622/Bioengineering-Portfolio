function [pct_cycle, knee_flexion_deg, grf_BW] = knee_gait_data()
% KNEE_GAIT_DATA  Returns normative walking gait cycle data:
%   - knee flexion angle (degrees) vs % gait cycle
%   - vertical ground reaction force (as multiples of body weight) vs %
%     gait cycle
%
% IMPORTANT - BE HONEST ABOUT THIS FOR YOUR DEFENSE:
% These are NOT a specific downloaded subject's OpenSim file. I could not
% fetch a real .mot file through my sandboxed web access (GitHub only
% serves it via git clone, not a direct link I'm allowed to fetch).
% These numbers are digitized approximations of the classic, widely
% published normative gait curves (the double-hump vertical GRF pattern
% and the knee flexion pattern with two flexion peaks - loading response
% ~15-20° and swing phase ~60-65°) described in:
%   Winter, D.A. (2009). Biomechanics and Motor Control of Human
%   Movement, 4th ed. - the standard reference every biomechanics course
%   cites for these exact curve shapes.
%
% This is a legitimate and defensible starting point ("I used
% literature-representative normative gait data"), but it is NOT the
% same claim as "I used a validated experimental OpenSim dataset" - say
% which one you actually did on your defense, don't blur the two.
%
% HOW TO UPGRADE TO A REAL OPENSIM FILE LATER (optional, if you install
% OpenSim locally - it's free):
%   1. Install OpenSim (https://opensim.stanford.edu) - the installer
%      bundles example data including Gait2392_Simbody with real
%      subject01_walk1_ik.mot (joint angles) and _grf.mot (ground
%      reaction forces) files, under the Models/Gait2392_Simbody folder.
%   2. Read them in MATLAB with the OpenSim API (org.opensim.modeling.*)
%      or simply open the .mot file as text (it's tab-delimited with a
%      header) and extract the knee_angle_r and ground_force columns.
%   3. Replace the arrays below with your extracted columns.

    pct_cycle = 0:5:100;

    knee_flexion_deg = [ ...
        5, 10, 15, 18, 15, 10, 6, 3, 2, 5, ...   % 0-45%: loading response + mid/terminal stance
        10, 20, 35, 50, 60, 55, 40, 25, 12, 5, ... % 50-95%: pre-swing through swing
        5];                                          % 100% = same as 0% (cycle closes)

    grf_BW = [ ...
        0, 0.6, 1.05, 1.15, 1.05, 0.85, 0.75, 0.78, 0.85, 1.0, ... % 0-45%: first peak, trough
        1.15, 0.9, 0.3, 0, 0, 0, 0, 0, 0, 0, ...                    % 50-95%: second peak, toe-off, swing (no ground contact)
        0];                                                          % 100%

    assert(numel(pct_cycle) == numel(knee_flexion_deg));
    assert(numel(pct_cycle) == numel(grf_BW));
end
