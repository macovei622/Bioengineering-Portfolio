# Detailed Theoretical Guide to Three Projects

This guide covers not only the general theory, but also what is actually
implemented in the source code and Simulink models of this repository. It is
intended for readers who want to be able to explain the workflow, justify the
chosen methods, understand the limitations, and compare the implementation with
possible alternatives.

It is important to distinguish three levels of statements:

1. **Physical or mathematical model** — the equation we want to describe.
2. **Numerical implementation** — the approximation of that equation in MATLAB or
   Simulink.
3. **Interpretation of the result** — what conclusions the data and assumptions
   allow.

A graph or high accuracy by itself does not make a simplified model a clinical
proof. In each project below, the assumptions and limits of reliable inference
are discussed separately.

## Project map at a glance

| Project | Question | Main method | Outcome |
|---|---|---|---|
| [EMG Gesture Classification](./Project_1_EMG_Processing/EMG.Classification/files/README.md) | Can multi-channel muscle activity signals be used to recognize gesture class? | Windowed features, LDA, linear SVM, and Extra Trees | Gesture label for each signal window and metrics on held-out repetitions |
| [Knee Joint Biomechanics](./Project_2_Knee_Biomechanics/README.md) | How do passive ligament forces change in a simplified model under a given gait cycle and ACL shutdown? | Prescribed kinematics and GRF, attachment geometry, nonlinear viscoelastic force | Time series of calculated forces and a conditional aggregate metric |
| [2D Scaffold Oxygen Diffusion](./Project_3_Scaffold_Diffusion/README.md) | How do channels of a given shape change the stationary oxygen field in a 2D scaffold? | Reaction-diffusion equation, finite differences, Jacobi iterations | Concentration field and the fraction of tissue below a chosen threshold |

The general portfolio principle is to choose a clear model, implement it in
MATLAB or Python, verify the calculations, and explicitly describe what the
model does **not** account for. These are good educational and research
prototypes, but not complete clinical or engineering systems.

---

# Project 1. Gesture classification from EMG

Source code: [EMG classification folder](./Project_1_EMG_Processing/EMG.Classification/files/README.md).
Main MATLAB workflow: [main_train_pipeline.m](./Project_1_EMG_Processing/EMG.Classification/files/main_train_pipeline.m).
Python port of the pipeline: [emg_pipeline.py](./Project_1_EMG_Processing/EMG.Classification/files/python/emg_pipeline.py).

## 1. What EMG measures

Electromyography records the electrical activity associated with muscle
excitation. Surface electrodes see a mixture of activity from many motor units,
not a direct command such as “perform a gesture.” The amplitude depends on at
least:

- which muscles and motor units are active;
- contraction strength and hand position;
- electrode placement, contact, and condition;
- anatomical differences between people;
- noise and instrumentation preprocessing.

Therefore, the algorithm learns a statistical relationship between the signal
and the gesture label in a given dataset. It does not “understand” the human
intent and does not prove that it will perform equally well on a different user.

### Specific feature of this dataset

The implementation uses NinaPro DB1: 10 channels with a sampling rate of 100 Hz.
The DB1 data are already represented as RMS-processed envelopes rather than raw
high-frequency EMG. This fundamentally changes the preprocessing:

- a step of 100 Hz means one sample every 10 ms;
- the data are already smoothed and rectified by hardware RMS processing;
- it is not automatically valid to apply the usual raw EMG filter of 20–450 Hz
  and a 50 Hz notch filter: in this representation, the original high-frequency
  components are no longer preserved.

The function [preprocess_emg.m](./Project_1_EMG_Processing/EMG.Classification/files/preprocess_emg.m)
checks the sampling frequency and finite values and deliberately does not apply
an additional filter to the envelope. This does not mean that filtering is
unnecessary for EMG in general; it means that the processing must match the type
of input. For raw signals from another dataset, a separate justified pipeline is
required.

## 2. Data and processing sequence

The converter
[convert_ninapro_csv_to_mat.m](./Project_1_EMG_Processing/EMG.Classification/files/convert_ninapro_csv_to_mat.m)
creates the EMG matrix and saves it together with:

- `restimulus` — the class label at each sample;
- `subject`, `exercise`, `repetition` — grouping metadata;
- `fs` — the sampling frequency, expected to be 100 Hz.

The metadata are needed not only to describe the dataset. They are necessary so
that the data can be split correctly into training and test sets. A matrix
without repetition information does not allow a reliable check of generalization
on an independent repetition.

The general sequence in `main_train_pipeline.m` is:

1. Load the MAT file and verify the required fields and `fs`.
2. Restrict the calculation to a continuous prefix of up to 100,000 samples so
   the pilot can run without processing the entire large dataset.
3. If the prefix boundary falls inside a repetition, cut the data at the end of
   the previous full group.
4. Segment the recordings into windows without crossing group boundaries.
5. Discard windows where the label is not sufficiently homogeneous.
6. Compute features for each window and each channel.
7. Split **groups**, not individual windows, into training and test.
8. Compute normalization only on the training data.
9. Train LDA and linear SVM in MATLAB; in Python also compare them with the
   balanced Extra Trees ensemble.
10. Show confusion matrices and save the model together with the normalization
    parameters.

The Python pipeline by default uses only exercise 1, because identical label
numbers in different exercises do not necessarily mean the same gesture.
The `--max-samples` limit sets the prefix of the original CSV, not the number of
samples in a single exercise: after selecting the exercise, the effective sample
size may be considerably smaller. Therefore, the short and extended runs assess
different sets of repetitions and should not be interpreted as the same test.

This direction of data flow can be written as:

```text
time signal + labels + repetition numbers
        ↓
windows and filtering of boundary/mixed windows
        ↓
40 features per window (4 features × 10 channels)
        ↓
group split → train-only normalization → classification
        ↓
metrics and confusion matrices on test groups
```

## 3. Windows: why and how

It is more convenient for the classifier to receive a fixed feature vector than
an unbounded continuous stream. Therefore, the signal is divided into short
segments:

- window length — 200 ms;
- sampling rate — 100 samples/s;
- therefore each window contains `0.2 × 100 = 20` samples;
- window step — 50 ms, i.e. 5 samples;
- adjacent windows overlap by 150 ms, or 75%.

The overlap allows more frequent gesture estimates without making each window
long. The downside is that adjacent windows are very similar. If windows are
accidentally shuffled before splitting, nearly identical segments may end up in
both training and test data. Then the test will mostly reflect recognition of
almost repeated material instead of generalization.

The function [segment_windows.m](./Project_1_EMG_Processing/EMG.Classification/files/segment_windows.m)
does not keep a window that crosses a `subject/exercise/repetition` boundary.
Additionally, at least 90% of the samples in a window must share the most common
label. For 20 samples, this means that at least 18 belong to the same class.
The label assigned to the accepted window is the mode of the labels inside it.
This rule removes windows that mainly consist of transitions between rest and a
gesture, or between two gestures.

The price of this solution is that transitional movements are not classified
fully, and the 90% threshold and the window length are design parameters. Another
project may deliberately recognize transitions, but then it needs labels and
criteria specific to the transition state.

## 4. Features: what is actually extracted

For each of the 10 channels and each window, four features are computed. The
result is a 40-element vector.

Let a single-channel window be the samples \(x_1, \ldots, x_N\).

### MAV — mean absolute value

\[
\operatorname{MAV} = \frac{1}{N}\sum_{i=1}^{N}|x_i|.
\]

In raw bipolar EMG, the magnitude prevents positive and negative phases from
canceling each other. For RMS envelopes, values are usually nonnegative; in that
case MAV primarily characterizes the average activation level.

### RMS — root mean square value

\[
\operatorname{RMS} =
\sqrt{\frac{1}{N}\sum_{i=1}^{N}x_i^2}.
\]

The square emphasizes larger samples more strongly. This is a generalized measure
of power/amplitude. Since the input dataset is already hardware-processed RMS,
this windowed RMS is another statistic of the recorded envelope, not a recovery
of the original hardware operation.

### WL — waveform length

\[
\operatorname{WL} = \sum_{i=1}^{N-1}|x_{i+1}-x_i|.
\]

WL sums the absolute changes between neighboring samples. It increases when the
signal changes more strongly within the window. This quantity depends on the
window length; it should be compared only at fixed window length and sampling
rate.

### SSC — number of sign changes in slope

The code evaluates neighboring slopes:

\[
 s_i = x_{i+1}-x_i
\]

and counts a point if \(s_i s_{i+1} < 0\), and the magnitudes of both slopes
exceed a cutoff. This is an approximate count of local turns/extrema. The
threshold reduces sensitivity to very small oscillations. In this pipeline, it
is set to 1% of the maximum magnitude of the training samples, i.e. parameter is
determined without looking at the test data.

SSC is not the same as the classical zero crossing: for a nonnegative RMS
envelope, transitions through zero carry almost no useful information. A change
in slope direction remains meaningful even for nonnegative signals.

The feature implementation is in
[extract_features.m](./Project_1_EMG_Processing/EMG.Classification/files/extract_features.m).

### Alternatives to the chosen features

- **Frequency-domain features** (for example, spectral characteristics) are useful
  when the input contains properly sampled raw EMG and the task depends on
  frequency content. At 100 Hz on the envelope, the available spectrum is
  different.
- **AR coefficients** model temporal structure but require choosing an order and
  careful estimation.
- **Wavelets** describe local changes in time and frequency simultaneously but
  increase dimensionality and complexity.
- **Trainable neural networks on raw sequences** can find complex patterns, but
  require substantially more data and correct checks across users, hyperparameter
  tuning, and overfitting control.

Manual temporal features were selected as a compact, interpretable, low-cost
baseline model. This is a good starting point, not proof that they are optimal.

## 5. Grouped splitting without leakage between repetitions

A group is defined by the combination of `subject`, `exercise`, and
`repetition`. All windows from one such group are placed either entirely in the
training set or entirely in the test set. This is called grouped splitting.

In the code, the `grouped_holdout` function randomly selects roughly 30% of the
available groups (fixed seed = 1) and attempts to keep all classes in both the
training and test data. Checking for all classes is useful because otherwise the
metric would not compare the same set of gestures. However, the algorithm is not
a full stratified procedure for a large number of groups: it explores random
options and stops after a limited number of attempts.

Splitting by repetition addresses the question:

> Can the model classify held-out repetitions of this participant if some other
> repetitions of the same participant were in training?

It does **not** answer:

> Will the model work on a person the model has never seen?

For that question, one needs to hold out an entire subject, e.g. leave-one-
subject-out or group-based cross-validation by subject. Random splitting of
windows would be even weaker because due to overlap, neighboring fragments of the
same recording could land on different sides of the split.

### Normalization and information leakage

For each feature \(j\), the training mean \(\mu_j\) and standard deviation
\(\sigma_j\) are computed, and both sets are transformed:

\[
 z_j = \frac{x_j - \mu_j}{\sigma_j}.
\]

The parameters are estimated only on the training data and then applied to the
test data without re-estimation. If the mean and standard deviation are computed
on all data, information about the test distribution leaks into training. This is
less catastrophic than directly using the test labels, but it still makes the
evaluation unfair.

In the code, `eps` is added to \(\sigma\) to avoid division by zero for a
constant feature. This does not create useful variability: a constant feature
remains practically zero.

## 6. Classifiers

### LDA — linear discriminant analysis

LDA estimates the feature distribution for each class. In the classical model,
classes have different means \(\mu_k\) but share a common covariance matrix
\(\Sigma\). For class \(k\), the discriminant function is

\[
\delta_k(x)=x^\mathsf{T}\Sigma^{-1}\mu_k
-\frac12\mu_k^\mathsf{T}\Sigma^{-1}\mu_k+\log \pi_k,
\]

where \(\pi_k\) is the prior class probability. The class with the largest
\(\delta_k(x)\) is chosen. The shared covariance produces linear boundaries
between classes; this is why the method is called “linear.”

LDA is attractive because it is fast, relatively compact, and suitable as a
transparent baseline model. Its limitations are that the common covariance
assumption may be too simple and the covariance estimate can be unstable with
redundant or dependent features.

In the current run, `DiscrimType='pseudoLinear'` was used. The reason is
practical: MATLAB reported zero within-class variance for one predictor. With a
singular or degenerate covariance matrix, the ordinary inverse does not exist or
is poorly conditioned. The pseudolinear variant allows this degeneracy via a
pseudo-inverse approach. This allows the model to be trained, but it does not
turn a constant feature into a useful one and does not replace feature
inspection.

Alternatives: remove constant features, regularize the covariance, or use
diagonal LDA. Removing strictly constant or near-constant features often makes
the root cause clearer. Diagonal covariance reduces the number of parameters to
estimate, but ignores feature correlations.

### Linear SVM and ECOC

A binary linear SVM seeks a hyperplane

\[
 w^\mathsf{T}x+b=0,
\]

which separates the classes with the widest possible margin and penalizes
violations. In the soft-margin setting, the penalty for errors is controlled by
\(C\): a large \(C\) tries harder to classify the training points correctly but
may overfit; a smaller \(C\) tolerates more errors in exchange for a smoother
decision boundary. The current code uses a linear kernel, but does not run a
separate systematic search for the optimal \(C\).

Because there are more than two gestures, `fitcecoc` combines binary SVMs via
Error-Correcting Output Codes. In the standard MATLAB multiclass scheme for this
call, pairwise classifiers are used: between each pair of classes, a binary
boundary is trained, and the final class is chosen from the combined vote/code.
This is often more accurate than binary “one-vs-all” for some tasks, but the
number of models grows roughly as the number of class pairs.

SVM does not require Gaussian features, but it is sensitive to the scale of the
predictors; therefore normalization is important. It can work well with compact
features, but the storage and deployment of the multiclass model should be
checked separately. It should not be assumed to be automatically “better” than
LDA based on a single accuracy value.

Other alternatives: RBF SVM for nonlinear boundaries, k-nearest neighbors,
trees/ensembles, regularized logistic regression, and neural networks. Each
requires tuning and honest validation; increasing model complexity does not by
itself guarantee improvement on new people.

## 7. Metrics and current results

In the original MATLAB pilot on held-out groups, the following were recorded:

- LDA: accuracy **74.4%**, balanced accuracy **67.4%**;
- linear SVM: accuracy **78.7%**, balanced accuracy **74.2%**;
- majority-class baseline: **27.0%**.

Accuracy is the fraction of all correct predictions:

\[
\operatorname{Accuracy} =
\frac{\text{number of correct predictions}}{\text{number of test windows}}.
\]

If the classes are imbalanced, accuracy can hide poor recognition of rare class
examples. Balanced accuracy first computes recall for each class and then averages
it:

\[
\operatorname{BalancedAccuracy}
=\frac{1}{K}\sum_{k=1}^{K}
\frac{TP_k}{TP_k+FN_k}.
\]

Thus, each class contributes equally to the final average. The confusion matrix
provides a more detailed answer: which classes are confused with one another.
The MATLAB matrices are in the
[images folder](./Project_1_EMG_Processing/images). For the Python check on an
expanded exercise-1 sample, Extra Trees showed **75.6% accuracy** and **71.4%**
balanced accuracy on one grouped split. This is a result on several available
subjects with held-out repetitions, but not an independent validation on unseen
people; the result depends on the chosen split. The code also saves LDA and SVM
confusion matrices.

The 27% baseline is the result of predicting the most frequent class from the
training portion for all test windows. It is useful as context, but it does not
replace stronger baseline models or comparison by groups.

This result is based on 99,925 samples from a single subject, split into
subject/exercise/repetition groups; three groups fell into the test set. At 100 Hz,
99,925 samples correspond to roughly 999 seconds of recording. Because all data
come from one subject, the accuracy is **not** an estimate of generalization to
unfamiliar users. Successful classification of held-out repetitions may still rely
on subject-specific features.

## 8. Simulink model and deployment

The script saves `chosen_model` (currently LDA), `mu`, `sigma`, the SSC threshold,
and the sampling frequency. The example code
[simulink_function_block.m](./Project_1_EMG_Processing/EMG.Classification/files/simulink_function_block.m)
uses a fixed buffer of 20 samples, i.e. 200 ms at 100 Hz, computes the same
features, and normalizes them using the saved parameters.

The block then takes the five most recent predictions and applies a majority
vote — a temporal smoothing step intended to reduce brief “chatter” in the labels.
Smoothing increases stability of the display but adds delay and may react more
slowly to a real gesture change.

There are two important engineering constraints here:

1. The block outputs a new prediction at every input sample after the buffer is
   filled, i.e. every 10 ms, while the training windows were shifted by 50 ms.
   The windows are the same length, but the update frequency and dependence on
   neighboring predictions differ. For a target system, this should be checked and
   configured deliberately.
2. `coder.extrinsic`, MAT-file loading, and calling `predict` are suitable for a
   normal MATLAB simulation, but they do not imply a ready-to-deploy microcontroller
   implementation. Before real deployment, one should implement the LDA calculation
   using coefficients/matrices, verify numerical equivalence, latency, memory use,
   safety, and behavior under signal loss.

**Conclusion for Project 1:** a full, interpretable baseline has been shown, from
multi-channel signal to model comparison. The next strong scientific step is an
evaluation with held-out subjects rather than simply increasing classifier
complexity.

---

# Project 2. Knee joint biomechanical model

Project description: [Project 2 README](./Project_2_Knee_Biomechanics/README.md).
Simulink model is in the project archive; input preparation —
[prepare_simscape_inputs.m](./Project_2_Knee_Biomechanics/prepare_simscape_inputs.m),
trajectories — [knee_gait_data.m](./Project_2_Knee_Biomechanics/knee_gait_data.m),
analysis of saved results —
[analyze_results.m](./Project_2_Knee_Biomechanics/analyze_results.m).

## 1. What question is being modeled

The project compares two scenarios under the same **prescribed** gait cycle:

- baseline ligament parameters;
- ACL disabled (its stiffness and damping in the model block are set to zero).

This is a model of passive ligament forces under prescribed kinematics, not a
full simulation of how a person changes gait after injury. The knee angle and
vertical ground reaction force are supplied as input signals. The model does not
solve how movement changes under the forces, does not model muscle control, and
does not predict clinical status.

## 2. Gait cycle inputs

`knee_gait_data.m` contains 21 manually specified points for a cycle from 0 to
100% in 5% increments. These are approximate normative curves based on Winter
(2009), not measurements of a particular person.

`prepare_simscape_inputs.m` converts the cycle percentages into a 1.1-second time
series. `pchip` interpolation with a 1 ms step is used between points. This
creates smooth time tables for the `From Workspace` inputs, but the dense grid
**does not add measurement accuracy**: values between sparse original points are
interpolated.

The angle is converted from degrees to radians because radians are used by the
internal rotation functions and are typical for mechanical blocks. The vertical
GRF is given in body-weight fraction and then multiplied by the weight of a
selected reference participant:

\[
W=mg=70\cdot 9.81=686.7\ \text{N},\qquad
F_{\mathrm{GRF}}(t)=\mathrm{GRF}_{BW}(t)\,W.
\]

70 kg is a configurable illustrative mass, not a patient mass. Negative values
in the interpolated GRF are clipped to zero because contact with the ground in
this simplified model does not pull the foot toward the surface.

### Why prescribed inputs are useful and where they are weak

Prescribed time series provide a reproducible comparison of parameters: both
scenarios receive the same trajectory, so the difference is associated with ACL
shutdown within this specific model. But this is a “comparison under fixed motion,”
not a dynamic prediction of a new gait pattern.

An alternative is to import synchronized measured kinematics and GRF for a
specific participant. A more complete variant would be inverse dynamics, muscle
moments/forces, and then forward dynamics, where movement responds to forces.
This is more realistic but requires substantially more data, parameters,
verification, and is harder to identify.

## 3. Ligament geometry

The built-in MATLAB Function `Ligament_Kinematics` in `knee_model.slx` describes
a 2D geometry in the sagittal plane. For angle \(\theta\), a rotation matrix is
formed:

\[
R(\theta)=
\begin{bmatrix}
\cos\theta & -\sin\theta\
\sin\theta & \cos\theta
\end{bmatrix}.
\]

For each ligament, the starting coordinates on the femur and the attachment
point on the tibia are specified. The femur point is fixed, and the tibia point
rotates:

\[
p_{\mathrm{tibia}}(\theta)=R(\theta)\,p_{\mathrm{tibia,local}}.
\]

The current length of the straight segment between the points is:

\[
L(\theta)=
\left\|p_{\mathrm{femur}}-
 p_{\mathrm{tibia}}(\theta)
ight\|_2.
\]

This yields four scalar lengths: ACL, PCL, MCL, and LCL. Time derivatives of the
lengths are estimated in the model using `Derivative` blocks and used as
elongation velocities.

The geometric scheme allows the knee angle to be related to changes in the
length of a representative ligament. But this is a simplified scheme of points
and one rotation axis. It does not describe 3D anatomy, articular surface
contact, axis movement, tissue deformation, or the complex ligament path around
the bones.

## 4. Ligament force law

The ligament must pull when stretched but not push when compressed. Let \(L_0\)
be the slack length and \(\Delta L = L - L_0\) be the elongation. In the Simulink
block, a piecewise law is used:

\[
F=
\begin{cases}
0, & \Delta L\leq 0,\
\max\left(0,\ K(\Delta L)^2+C\dot L
ight), & \Delta L>0.
\end{cases}
\]

Here:

- \(K\) — quadratic stiffness coefficient, units N/m²;
- \(C\) — viscous damping, units N·s/m;
- \(\dot L\) — length-change velocity, m/s.

The quadratic term models increasing stiffness at larger elongation. The viscous
term depends on velocity and adds resistance to rapid stretching. The lower bound
of zero prevents negative force from being treated as ligament compression. This
is a simple nonlinear spring-damper with a slack threshold.

Alternatives:

- Linear law \(F=k\Delta L\) is simpler and easier to calibrate, but stiffness
does not change with elongation;
- more realistic piecewise-nonlinear or exponential laws can describe tissue more
  accurately but require experimental parameters;
- viscoelastic memory models (for example, standard linear solid) describe
  dependence on deformation history rather than only current velocity and length;
- finite elements can model distributed deformation but require geometry and
  material properties.

### Important discrepancy between the two files

The law inside `knee_model.slx` sets its own slack lengths and coefficients: for
example, \(L_{0,ACL}=0.038\) m, \(K_{ACL}=5\cdot10^6\) N/m², and
\(C_{ACL}=50\) N·s/m. The external file [ligament_force.m](./Project_2_Knee_Biomechanics/ligament_force.m)
contains illustrative values in comments that **do not match** the parameters
inside the embedded function of the archive. The embedded Simulink block does not
automatically call the external function. Therefore, to reproduce the results,
one must inspect the actual model block; the comments in `ligament_force.m` alone
are insufficient to determine the parameters actually used.

The parameters are labeled as illustrative rather than measured for a particular
ligament or patient. The calculated force is therefore a result of the specified
assumptions, not a measured biological force.

## 5. What the model calls the joint reaction

The top-level Simulink diagram has a summation block with five inputs: the
vertical GRF and four scalar ligament forces. They are summed with the same sign.
The output is stored as `knee_reaction_force`.

This must be explained precisely: in the current diagram, this output is a
**scalar sum of specified quantities**, not a full three-dimensional joint
reaction derived from a vectorial force balance. The ligament forces act along
different lines of action; to obtain a vector resultant, one would need the
direction vectors of tension, project the forces onto axes, and define a
consistent coordinate system and free-body equations. A proper joint reaction
analysis would also require a balanced treatment of external forces, inertial
terms, and contact forces. The current sum is only a simplified comparative
indicator.

A true vector resultant would require, for each ligament, computing a unit
vector along its line of action, converting the force into components, setting a
reference frame, and explicitly writing equilibrium or dynamics equations. Then
the output names and the analysis would need to be updated accordingly.

## 6. Results and valid interpretation

The project README notes the following for the saved results:

- baseline case: ACL peak around 125.6 N, conditional aggregate metric around
  1239.6 N;
- ACL disabled: ACL force is zero, peak conditional metric around 1114.1 N;
- PCL, MCL, and LCL in these saved scenarios do not change.

Why do the other ligaments not redistribute the load? Because the knee angle and
GRF are prescribed, the geometry of the remaining ligaments remains unchanged,
and the model does not solve an inverse dynamic problem or modify movement. The
values primarily show the arithmetic effect of removing one member from a five-
term sum under the same kinematics. This does not prove that human ligaments
really do not bear more load after ACL rupture.

The README also notes that the comparative figure in the image folder predates
the clarified naming. Do not present the old figure as a guaranteed updated
visualization of the current scenario until it is recreated from the current
results.

## 7. Why Simulink and possible alternatives

Simulink helps visually show the flow of inputs, kinematic computation,
derivatives, forces, and saving of results. MATLAB Function blocks are convenient
for writing equations. However, using Simulink does not automatically make the
model physically complete. The archived model mainly uses analytical blocks/
functions and prescribed inputs; the script name `prepare_simscape_inputs.m` does
not imply that all bones and tissues are represented as full Simscape Multibody
bodies with contact.

Possible further developments:

1. **Improve the existing analytical prototype.** Move from summing magnitudes to
   force components, check signs and units, add limit-case tests, and centralize
   parameters as a single input source.
2. **Use measured motion and GRF.** This improves the specificity of the input,
   but does not automatically resolve the issue of internal loading.
3. **Add a musculoskeletal model / inverse dynamics.** This requires kinematic
   data, external forces, anthropometry, and a muscle model.
4. **Move to 3D geometry or finite elements.** This can be more detailed but
   requires substantially more experimental parameters and validation.

**Conclusion for Project 2:** the project demonstrates the relationship between
kinematics, geometry, nonlinear tension law, and scenario comparison. For strong
biomechanical conclusions, the vector force balance and parameter validation
must be clarified first, rather than merely complicating the plots.

---

# Project 3. 2D oxygen diffusion in a scaffold

MATLAB code: [scaffold_diffusion.m](./Project_3_Scaffold_Diffusion/scaffold_diffusion.m).
Python port: [scaffold_diffusion.py](./Project_3_Scaffold_Diffusion/python/scaffold_diffusion.py).
Description and caveats: [Project 3 README](./Project_3_Scaffold_Diffusion/README.md).

## 1. Physical meaning

Oxygen is transported from the nutrient medium through the scaffold material to
cells that consume it. Diffusive transport is described by Fick’s law. If the
concentration changes over time, the general form of the equation is:

\[
\frac{\partial C}{\partial t}
=D\nabla^2 C-R(C),
\]

where:

- \(C\) — oxygen concentration, mol/m³;
- \(D\) — diffusion coefficient, m²/s;
- \(\nabla^2 C\) — spatial curvature/Laplacian of concentration;
- \(R(C)\) — consumption rate by cells, mol/(m³·s).

The current script does not solve the transient process; it solves the steady-
state balance:

\[
D\nabla^2 C-R=0.
\]

In steady state, local oxygen supply by diffusion on average balances the
consumption. Here \(R=R_{\max}\) is constant, meaning a **zero-order consumption**
model is used: cells consume at the same rate for any concentration until the
numerical scheme reaches a negative value. In reality, the consumption rate is
usually concentration-dependent; the model simplifies this.

## 2. Parameters and grid scaling

The code specifies:

- domain size \(L=2\) mm;
- square grid \(150\times150\);
- \(D=2\cdot10^{-9}\) m²/s;
- \(R_{\max}=2.5\cdot10^{-3}\) mol/(m³·s);
- medium concentration \(C_0=0.2\) mol/m³;
- hypoxia/necrosis threshold \(C_{\mathrm{crit}}=0.02\) mol/m³.

Spatial step between nodes:

\[
\Delta x=\frac{L}{N-1}
\approx 13.42\ \text{µm}.
\]

This is a 2D computational grid; a pixel/node should not automatically be
interpreted as a cell. Spatial resolution is determined by the number of nodes
and the chosen domain size.

Dimension analysis is important. The term \(D\nabla^2 C\) has units of
mol/(m³·s), just like \(R\), so they can appear in the same equation.

## 3. Geometry and boundary conditions

The mask is a matrix where `1` denotes tissue/hydrogel with cells and `0`
denotes the medium with fixed concentration \(C_0\).

Two cross-sections are considered:

1. **Solid material:** only the outer edges have \(C=C_0\).
2. **Material with channels:** the same outer edges plus a manually specified
   regular grid of horizontal and vertical channels with \(C=C_0\).

A fixed concentration at the surface is a Dirichlet condition. The physical idea:
the boundary or perfused channel maintains the medium’s fixed concentration.
The channels do not model fluid flow and pressure drop; they are idealized oxygen
reservoirs with constant \(C_0\).

The geometry of the channels is defined in the script: `spacing = round(N/4)` and
`width = 3`; around the selected rows and columns, the mask is converted to zero.
`width` here is half the width of the index range: effectively, 7 nodes are used
in a row. At this scale, this is roughly 94 µm between the farthest centers on
the grid, with line spacing of about 510 µm. These numbers are properties of the
current discretization and hand-made geometry, not measured dimensions of an
optimal scaffold.

## 4. Finite-difference method

Inside the tissue in the 2D Cartesian case, the Laplacian is approximated by the
central difference formula:

\[
\nabla^2C_{i,j}\approx
\frac{C_{i+1,j}+C_{i-1,j}+C_{i,j+1}+C_{i,j-1}-4C_{i,j}}
{\Delta x^2}.
\]

Substituting this into the steady-state equation \(D\nabla^2C-R=0\) yields the
center value:

\[
C_{i,j}=
\frac{C_{i+1,j}+C_{i-1,j}+C_{i,j+1}+C_{i,j-1}}{4}
-\frac{R\Delta x^2}{4D}.
\]

The code defines

\[
\alpha=\frac{R\Delta x^2}{D}
\]

and at each step computes the mean of the four neighbors minus \(\alpha/4\).
The array index shifts implement this operation vectorially without an explicit
nested loop across every pixel.

The central finite-difference approximation is simple and clear on a uniform
square grid. Its accuracy depends on the step size and geometry; curved
boundaries and complex structures are represented stepwise.

## 5. Jacobi iterations

The equation at each node relates its concentration to its neighbors. Instead of
solving all unknowns simultaneously, the Jacobi method repeatedly updates values:

1. take the current grid \(C^{(k)}\);
2. for each tissue point, compute the new value from the neighbor values of the
   previous grid;
3. restore the boundary nodes and channels to concentration \(C_0\);
4. repeat until the difference between successive iterations is small.

Initializing the whole grid with \(C_0\) is the initial approximation for the
iterative algorithm; since the equation is steady-state, this is not a claim that
the physical transient process begins with uniform saturation.

The script checks convergence every 500 iterations and stops when the maximum
absolute difference between successive states is less than \(10^{-6}\). There is
an iteration cap of 20,000. If the cap is reached without convergence, the code
does not issue an explicit warning/status; this should be improved so the user
can distinguish a converged solution from a stop caused by the limit.

The iterative method was chosen because it is easy to show, debug, and
vectorize in MATLAB. The cost is potentially slow convergence. For a linear
equation on a grid, one can assemble a sparse matrix and solve the system
directly; for faster iteration, Gauss–Seidel or SOR are also possible. For
complex geometries and boundary conditions, finite volumes or finite elements are
an alternative.

## 6. Limitation due to negative concentrations

After computing the updates, the code performs:

```matlab
C_new(C_new < 0) = 0;
```

Physically, concentration cannot be negative, but clipping values is not a
neutral mathematical operation. If the chosen \(R,D,L\) cause the zero-order
solution to go below zero, clipping changes the problem: in regions where
\(C=0\), the consumption term is still included in the formula, but the value is
forced back to zero. Therefore, the result should be interpreted as an
approximate field with a lower bound, not as the exact solution of the original
linear PDE at every node.

A more physical alternative is to make consumption depend on concentration, for
example via saturation kinetics:

\[
R(C)=R_{\max}\frac{C}{K_m+C},
\]

or another experimentally justified description. Then the equation becomes
nonlinear, and nonlinear iterations/solvers are required. The choice of
\(R(C)\) requires biological data and should not be arbitrary.

## 7. “Necrosis” as a computed indicator

The script identifies a tissue node as below threshold if \(C<C_{\mathrm{crit}}\).
The fraction of “necrotic pixels” is computed only among nodes where `mask == 1`:

\[
\%_{\mathrm{below\ threshold}}=
100\frac{\#\{\text{tissue nodes with }C<C_{\mathrm{crit}}\}}
{\#\{\text{tissue nodes}\}}.
\]

This is an operational definition based on a single chosen threshold. It does not
model cell death over time, oxygen kinetics, migration, tissue growth,
perfusion, or biological variability. Therefore, the term “necrosis” here means
a region below the threshold in the computational model, not an observed
biological outcome.

The fraction of living tissue in the script uses a different denominator — the
entire grid \(N^2\), including channels and the boundary. For a porous geometry,
the difference between total area, tissue area, and oxygen-reservoir area is
significant. These percentages should not be mixed.

The README reports for the original geometries: 31.4% of tissue below threshold
in the solid mask and 0.0% in the channel mask; living tissue is 66.8% and 71.7%
of the full grid, respectively; wide channels remove about 26.4% of the original
tissue area. A limited search over regular geometries found one configuration with
one narrow channel in each direction: in the current model, this leaves 96.0% of
the grid viable. This is the best result among the tested templates, not a
physically optimal diameter or a biologically validated prediction. These values
are not guaranteed for a different grid, channel width, or cell kinetics.

In the project folder, the heat map is labeled in the README as prior to the
clarification of descriptions. Before using it as a final figure, it should be
rebuilt from the current script and the labels/scales checked.

## 8. Method choice and serious alternatives

**Why 2D + FDM + Jacobi?** This is a compact, reproducible way to connect
oxygen diffusion, consumption, and channel geometry. It shows the core idea:
additional sources at the boundary reduce the distance oxygen must travel through
a consuming tissue.

**What could be better for other goals?**

- **Stationary sparse system:** a good next step for the same linear PDE; faster
  and allows control of residual error.
- **FVM:** naturally preserves mass balance and is convenient for flows and
  nonuniform regions.
- **FEM:** more flexible for complex geometry and heterogeneous properties, but
  requires control of the mesh and weak-form formulation.
- **Transient PDE:** shows how quickly oxygen reaches steady state, but requires
  initial conditions and time integration.
- **3D model:** accounts for spatial distribution of channels through thickness,
  but sharply increases computational cost and geometric requirements.
- **Perfusion/flow model in channels:** instead of a fixed \(C_0\), it can account
  for concentration drop along the channel and mass transfer through the wall.
- **Geometry optimization:** compares different channel diameters/spacing while
  accounting not only for oxygen access, but also mechanical strength,
  manufacturability, and fraction of lost tissue.

Before concluding that a scaffold is “optimal,” at least a grid-convergence
study, sensitivity analysis for \(D,R,C_0,C_{\mathrm{crit}}\), geometry,
verification of dimensions, and experimental validation are needed.

**Conclusion for Project 3:** the model clearly demonstrates the impact of
distance to the oxygen source under fixed assumptions and includes a limited
search over regular 2D geometries. It does not optimize a branching structure,
does not model channel flow, and does not prove biological effectiveness.

---

# How the projects are related and how they differ

## Overall logic

In all three tasks, there are:

1. input data or parameters;
2. a simplified representation of the biological object;
3. a computational procedure;
4. a measurable output;
5. a question of how far the output can be generalized.

However, the nature of the conclusion differs:

- EMG — **statistical prediction** of a label for signals similar to the training
  data;
- knee — **mechanistic calculation** of forces from prescribed kinematics,
  geometry, and parameters;
- scaffold — **numerical approximation of a PDE field** on a grid.

Accuracy cannot be compared directly with force in newtons or concentration:
these are different quantities and different kinds of validation.

## Verification and validation are not the same thing

- **Verification:** does the code correctly implement the chosen equations? For
  example, do the formulas match on a test case, are units respected, and does the
  numerical solver converge?
- **Validation:** are the chosen equations sufficiently representative of the real
  system for the stated question? Independent measurements/experiments and error
  criteria are needed.

The code can be error-free and still answer only a narrow question because the
physical model is simplified. Conversely, a good theory does not excuse an error
in indices, train/test leakage, or wrong units.

## How to explain results better in a presentation

For each project, it helps to answer five questions:

1. **What is measured or specified as input?**
2. **What equation or algorithm transforms the input into the output?**
3. **Why was this level of complexity chosen?**
4. **How was the quality of the result checked?**
5. **What conditions do the conclusions not extend to?**

An example of a correct formulation for EMG: “On held-out repetitions from three
participants in the expanded exercise-1 sample, Extra Trees reached 75.6%
accuracy and 71.4% balanced accuracy on one split; this is not an estimate for
new participants.”

An example for the knee: “Under fixed approximate input trajectories and chosen
parameters, disabling the ACL removes its contribution from the conditional force
sum; the model does not recompute compensatory motion and is not a prediction of
patient instability.”

An example for the scaffold: “In this 2D steady-state model with constant
consumption, the specified channel grid increased the fraction of tissue nodes
above the selected threshold; this is not an experimental demonstration of cell
survival.”

---

# Mini-dictionary

- **Sample:** one measured signal value at a specific moment.
- **Sampling rate:** number of samples per second, Hz.
- **Window:** a limited time segment of a signal used to compute features.
- **Feature:** a number describing a portion of the signal/object for the
  classifier.
- **Label:** the known target class, such as a gesture.
- **Train/test:** datasets used for fitting/learning and independent evaluation.
- **Grouped split:** entire dependent groups are assigned to one side so related
  examples are not mixed across train and test.
- **Data leakage:** use of information from the test set during training or
  tuning.
- **Accuracy:** fraction of correct classifications among all examples.
- **Recall:** fraction of instances of a given class that the classifier finds.
- **Balanced accuracy:** mean recall across classes.
- **GRF:** ground reaction force.
- **ACL/PCL/MCL/LCL:** anterior/posterior cruciate and medial/lateral collateral
  ligaments.
- **PDE:** partial differential equation relating a field and its spatial/temporal
  changes.
- **FDM:** finite difference method.
- **Dirichlet boundary condition:** specified field value at the boundary.
- **Jacobi iterations:** repeated grid updates using values from the previous
  iteration.
- **Convergence:** approach of a numerical solution to a stable state under a chosen
  criterion.
- **Model sensitivity:** how strongly the output changes under parameter or
  assumption changes.

# Priority next steps

1. **EMG:** perform evaluation with an entire subject (or several subjects) held
   out, then present metrics per subject with confidence intervals. Compare window
   size/step and parameters on an internal grouped validation without tuning them
   on the final test set.
2. **Knee:** formulate free-body and component-wise forces, convert each ligament
   tension into a vector, eliminate duplicate parameters between the external `.m`
   file and embedded Simulink code, and add tests for units and limit cases. Then
   compare at least one time series with measurements or published data.
3. **Scaffold:** report convergence status and residuals; perform a grid
   convergence study, sensitivity analysis for key parameters, and compare with a
   sparse solution. Update the illustration after verifying labels and scales.

These steps improve the evidential strength of the projects: they strengthen the
checks of generalization, physical consistency, and quantitative reliability —
three different aspects of model quality.
