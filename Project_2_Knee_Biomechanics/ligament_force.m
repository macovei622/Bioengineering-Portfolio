function F = ligament_force(delta_x, v, K, C, x_slack)
%#codegen
% LIGAMENT_FORCE  Nonlinear ligament force law, as discussed:
%   F = K * delta_x^2 + C * v      (only when stretched beyond slack length)
%   F = 0                          (ligaments only pull, never push/compress)
%
% PASTE THIS INSIDE A "MATLAB Function" BLOCK IN YOUR SIMSCAPE MODEL,
% connected via Simulink-PS Converter / PS-Simulink Converter blocks,
% because the built-in "Translational Spring Damper" block in Simscape
% is LINEAR ONLY (F = K*x + C*v) - it cannot implement the quadratic
% term we discussed for ligament stiffening near full stretch. This is
% exactly why you need a custom block here instead of the library one.
%
% Inputs (all as plain doubles, connected via PS-Simulink Converters):
%   delta_x  - current stretch of the ligament attachment points (m),
%              measured relative to their distance at x_slack
%   v        - rate of change of that stretch (m/s)
%   K        - stiffness coefficient (N/m^2) - tune per ligament:
%              ACL/PCL are stiffer than MCL/LCL in most literature models
%   C        - damping coefficient (N*s/m)
%   x_slack  - slack length (m) below which the ligament goes slack and
%              carries zero force (ligaments are not springs in
%              compression - they just go slack, like a rope)
%
% Output:
%   F - tension force (N), always >= 0 (ligaments only pull)

    stretch = delta_x - x_slack;

    if stretch <= 0
        F = 0;
    else
        F = K * stretch^2 + C * v;
        if F < 0
            F = 0; % never let damping term make tension go negative
        end
    end
end

% SUGGESTED STARTING VALUES FOR THE DEFENSE (cite that these are
% illustrative/order-of-magnitude, not subject-specific measured values -
% real ligament stiffness varies hugely between studies and subjects):
%   ACL: K = 200000 N/m^2, C = 50 N*s/m, x_slack = 0 (already near taut)
%   PCL: K = 250000 N/m^2, C = 50 N*s/m, x_slack = 0
%   MCL: K = 100000 N/m^2, C = 30 N*s/m, x_slack = 0.002 m
%   LCL: K = 90000  N/m^2, C = 30 N*s/m, x_slack = 0.002 m
% For the "ACL injury" case discussed: set ACL's K = 0 and C = 0, rerun,
% compare peak MCL/LCL force and joint reaction force to the intact case.
