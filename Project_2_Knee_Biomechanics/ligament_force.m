function F = ligament_force(delta_x, v, K, C, x_slack)
%#codegen
% LIGAMENT_FORCE  Nonlinear tensile ligament force law:
%   F = K * delta_x^2 + C * v      (only when stretched beyond slack length)
%   F = 0                          (ligaments only pull, never push/compress)
%
% This function can be used in a MATLAB Function block with Simulink-PS
% and PS-Simulink Converter blocks. It implements a quadratic stiffness
% term that a linear translational spring-damper block does not provide.
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

% Illustrative starting values only; these are not subject-specific
% measured parameters:
%   ACL: K = 200000 N/m^2, C = 50 N*s/m, x_slack = 0 (already near taut)
%   PCL: K = 250000 N/m^2, C = 50 N*s/m, x_slack = 0
%   MCL: K = 100000 N/m^2, C = 30 N*s/m, x_slack = 0.002 m
%   LCL: K = 90000  N/m^2, C = 30 N*s/m, x_slack = 0.002 m
% To model an ACL-disabled case, set ACL K and C to zero and rerun.
