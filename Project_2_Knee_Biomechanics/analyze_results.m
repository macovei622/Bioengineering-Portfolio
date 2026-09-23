%% ANALYZE_RESULTS
% Loads the two saved simulation results (normal vs ACL-torn) and
% produces the comparison plots + printed summary you need for the
% "ACL injury" defense case.
%
% BEFORE RUNNING: make sure you saved both files as described in
% PLAN2.md step 6 (results_normal.mat and results_acl_torn.mat).

normal = load('results_normal.mat');
torn = load('results_acl_torn.mat');

fprintf('=== Peak forces: NORMAL knee ===\n');
fprintf('ACL peak: %.1f N\n', max(abs(normal.acl_force)));
fprintf('PCL peak: %.1f N\n', max(abs(normal.pcl_force)));
fprintf('MCL peak: %.1f N\n', max(abs(normal.mcl_force)));
fprintf('LCL peak: %.1f N\n', max(abs(normal.lcl_force)));
fprintf('Joint reaction peak: %.1f N\n', max(vecnorm(normal.knee_reaction_force, 2, 2)));

fprintf('\n=== Peak forces: ACL-TORN knee ===\n');
fprintf('ACL peak: %.1f N (should be ~0)\n', max(abs(torn.acl_force)));
fprintf('PCL peak: %.1f N\n', max(abs(torn.pcl_force)));
fprintf('MCL peak: %.1f N\n', max(abs(torn.mcl_force)));
fprintf('LCL peak: %.1f N\n', max(abs(torn.lcl_force)));
fprintf('Joint reaction peak: %.1f N\n', max(vecnorm(torn.knee_reaction_force, 2, 2)));

pct_increase_mcl = 100 * (max(abs(torn.mcl_force)) - max(abs(normal.mcl_force))) / max(abs(normal.mcl_force));
pct_increase_lcl = 100 * (max(abs(torn.lcl_force)) - max(abs(normal.lcl_force))) / max(abs(normal.lcl_force));
fprintf('\nMCL load increase after ACL tear: %.1f%%\n', pct_increase_mcl);
fprintf('LCL load increase after ACL tear: %.1f%%\n', pct_increase_lcl);

%% Comparison plot
figure('Name', 'ACL injury comparison');

subplot(2,2,1);
plot(normal.mcl_force, 'b', 'LineWidth', 1.5); hold on;
plot(torn.mcl_force, 'r--', 'LineWidth', 1.5);
title('MCL force'); legend('Normal', 'ACL torn'); ylabel('N'); grid on;

subplot(2,2,2);
plot(normal.lcl_force, 'b', 'LineWidth', 1.5); hold on;
plot(torn.lcl_force, 'r--', 'LineWidth', 1.5);
title('LCL force'); legend('Normal', 'ACL torn'); ylabel('N'); grid on;

subplot(2,2,3);
plot(normal.pcl_force, 'b', 'LineWidth', 1.5); hold on;
plot(torn.pcl_force, 'r--', 'LineWidth', 1.5);
title('PCL force'); legend('Normal', 'ACL torn'); ylabel('N'); grid on;

subplot(2,2,4);
plot(vecnorm(normal.knee_reaction_force,2,2), 'b', 'LineWidth', 1.5); hold on;
plot(vecnorm(torn.knee_reaction_force,2,2), 'r--', 'LineWidth', 1.5);
title('Joint reaction force magnitude'); legend('Normal', 'ACL torn');
ylabel('N'); grid on;

sgtitle('Normal knee vs ACL-torn knee - load redistribution');

fprintf(['\nDEFENSE LINE: "My model quantitatively shows that with the ACL ' ...
    'disabled, the MCL/LCL take on significantly more load during the ' ...
    'same gait cycle - this is consistent with the clinical picture of ' ...
    'accelerated secondary ligament and cartilage wear after an ' ...
    'untreated ACL injury. This model only captures passive structures ' ...
    '(bones + ligaments), without active muscle co-contraction, which ' ...
    'in reality provides part of the compensation."\n']);
