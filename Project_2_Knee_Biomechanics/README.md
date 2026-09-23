# Knee Joint Biomechanics: ACL Tear Simulation

## 📝 Overview
This project simulates the passive biomechanical stabilization of the human knee joint during a normal walking gait cycle (1.1s). It quantitatively evaluates the redistribution of joint reaction forces when the Anterior Cruciate Ligament (ACL) is ruptured.

## ⚙️ Mathematical & Engineering Approach
Unlike standard 3D visual physics engines, this model is built from the ground up using **Analytical Simulink blocks**:
1. **Kinematics:** Rotation matrices convert gait cycle flexion angles ($\theta$) into ligament elongations.
2. **Dynamics:** Connective tissue is modeled via non-linear viscoelastic equations (quadratic stiffness zone + linear damping, working only under tension).
3. **Simulation:** Computes the joint's net reaction force by summing Ground Reaction Forces (GRF) and passive ligament constraints.

## 📊 Results: Normal vs. ACL-Torn Knee
*(See the /images folder for comparative plots)*

**Key Findings:**
* **Intact Knee:** The ACL absorbs a peak load of ~125.6 N during the stance phase. The total joint reaction force reaches 1239.6 N.
* **ACL Rupture:** Setting ACL stiffness to zero drops the joint's restraining force exactly by 125.6 N. Due to the 1-DOF kinematic constraint of the model, collateral ligaments (MCL/LCL) maintain baseline loads, quantitatively proving the loss of anterior stability and the necessity of active muscular co-contraction.

## 🚀 How to Run
1. Open MATLAB and navigate to this folder.
2. Load inputs via `prepare_simscape_inputs.m`
3. Run `knee_model.slx` via Simulink.
4. Execute `analyze_results.m` to generate comparative plots.