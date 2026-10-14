# Knee Joint Biomechanics: ACL-Disabled Case

## 📝 Overview
This project calculates passive ligament forces and joint reaction forces over a prescribed 1.1 s gait cycle, then compares a baseline case with a case in which ACL stiffness is set to zero.

## ⚙️ Mathematical & Engineering Approach
Unlike standard 3D visual physics engines, this model is built from the ground up using **Analytical Simulink blocks**:
1. **Kinematics:** Rotation matrices convert gait cycle flexion angles ($\theta$) into ligament elongations.
2. **Dynamics:** Connective tissue is modeled via non-linear viscoelastic equations (quadratic stiffness zone + linear damping, working only under tension).
3. **Simulation:** Computes the joint's net reaction force by summing Ground Reaction Forces (GRF) and passive ligament constraints.

## 📊 Results: Normal vs. ACL-Torn Knee
*(See the [images](./images) folder for comparative plots.)*

**Key Findings:**
* **Baseline:** The modeled ACL force peaks at ~125.6 N; the joint reaction force peaks at ~1239.6 N.
* **ACL disabled:** The ACL force is zero and the peak joint reaction force is ~1114.1 N, a difference of ~125.6 N in these saved results. PCL, MCL, and LCL force traces are unchanged because the prescribed kinematics do not model compensatory motion or load redistribution to those ligaments.

These are outputs of a simplified passive model, not a clinical demonstration of anterior knee instability or a prediction of muscle compensation. The gait curves are 21 manually specified approximate normative points based on Winter (2009), not subject-specific measurements. Ligament parameters are illustrative.
The checked-in comparison plot predates the clarified “ACL disabled” terminology; regenerate it from `analyze_results.m` before presenting it.

## 🚀 How to Run
1. Extract `A model of knee joint loading during gait.zip` into this folder.
2. Open MATLAB and navigate to the extracted project folder.
3. Run `prepare_simscape_inputs.m` to create the prescribed gait input signals.
4. Run `knee_model.slx` in Simulink and save the baseline and ACL-disabled outputs as `results_normal.mat` and `results_acl_torn.mat`.
5. Run `analyze_results.m` to generate comparative plots and force summaries.