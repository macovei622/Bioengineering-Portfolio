%% ANALYZE_RESULTS
% Load baseline and ACL-disabled simulation outputs and compare forces.
%
% Run from the extracted project folder containing results_normal.mat and
% results_acl_torn.mat. The archive includes example result files.

normal = load('results_normal.mat');
torn = load('results_acl_torn.mat');

fprintf('=== Peak forces: baseline knee ===\n');
fprintf('ACL peak: %.1f N\n', max(abs(normal.acl_force)));
fprintf('PCL peak: %.1f N\n', max(abs(normal.pcl_force)));
fprintf('MCL peak: %.1f N\n', max(abs(normal.mcl_force)));
fprintf('LCL peak: %.1f N\n', max(abs(normal.lcl_force)));
fprintf('Joint reaction peak: %.1f N\n', max(vecnorm(normal.knee_reaction_force, 2, 2)));

fprintf('\n=== Peak forces: ACL-disabled case ===\n');
fprintf('ACL peak: %.1f N (should be ~0)\n', max(abs(torn.acl_force)));
fprintf('PCL peak: %.1f N\n', max(abs(torn.pcl_force)));
fprintf('MCL peak: %.1f N\n', max(abs(torn.mcl_force)));
fprintf('LCL peak: %.1f N\n', max(abs(torn.lcl_force)));
fprintf('Joint reaction peak: %.1f N\n', max(vecnorm(torn.knee_reaction_force, 2, 2)));

fprintf('\nMaximum absolute force-trace differences (ACL-disabled minus baseline):\n');
fprintf('PCL: %.6g N\n', max(abs(torn.pcl_force - normal.pcl_force)));
fprintf('MCL: %.6g N\n', max(abs(torn.mcl_force - normal.mcl_force)));
fprintf('LCL: %.6g N\n', max(abs(torn.lcl_force - normal.lcl_force)));

%% Comparison plot
figure('Name', 'ACL-disabled case comparison');

subplot(2,2,1);
plot(normal.mcl_force, 'b', 'LineWidth', 1.5); hold on;
plot(torn.mcl_force, 'r--', 'LineWidth', 1.5);
title('MCL force'); legend('Baseline', 'ACL disabled'); ylabel('N'); grid on;

subplot(2,2,2);
plot(normal.lcl_force, 'b', 'LineWidth', 1.5); hold on;
plot(torn.lcl_force, 'r--', 'LineWidth', 1.5);
title('LCL force'); legend('Baseline', 'ACL disabled'); ylabel('N'); grid on;

subplot(2,2,3);
plot(normal.pcl_force, 'b', 'LineWidth', 1.5); hold on;
plot(torn.pcl_force, 'r--', 'LineWidth', 1.5);
title('PCL force'); legend('Baseline', 'ACL disabled'); ylabel('N'); grid on;

subplot(2,2,4);
plot(vecnorm(normal.knee_reaction_force,2,2), 'b', 'LineWidth', 1.5); hold on;
plot(vecnorm(torn.knee_reaction_force,2,2), 'r--', 'LineWidth', 1.5);
title('Joint reaction force magnitude'); legend('Baseline', 'ACL disabled');
ylabel('N'); grid on;

sgtitle('Baseline vs ACL-disabled case (prescribed kinematics)');

fprintf(['\nInterpretation: with prescribed kinematics, disabling the ACL ' ...
    'changes the modeled ACL contribution and joint reaction force. ' ...
    'This model does not calculate compensatory motion or increased ' ...
    'PCL/MCL/LCL loading, and it does not establish a clinical outcome.\n']);
