# Preliminary Risk-Management File

## Status and method

This file is a preliminary, qualitative risk screen for the educational
software boundary in [system-scope.md](./system-scope.md). It is informed by
the risk-management process described in ISO 14971, but is not a completed
ISO 14971 risk-management file and does not establish conformity.

No organization-approved severity scale, probability scale, risk-acceptability
matrix, or residual-risk policy has been defined. The qualitative terms below
are prompts for prioritizing review, not formal risk estimates:

- **Potential severity:** Low = misleading or unusable analysis without
  foreseeable physical harm within this software boundary; Moderate = a
  plausible pathway to non-serious harm if outputs are misused or integrated;
  High = a plausible pathway to serious physical harm in a future actuator or
  clinical integration.
- **Likelihood:** Unclassified for all entries. The repository has no
  exposure model, field-use data, or reliability evidence from which to
  estimate occurrence.
- **Residual risk:** Not determined. A control's presence does not close a
  risk. A responsible organization must define acceptability criteria and
  evaluate residual risks for a specific intended use.

## Risk register

| ID | Project / hazard | Foreseeable sequence and hazardous situation | Potential harm | Preliminary severity | Existing control or information | Evidence and remaining action | Status |
|---|---|---|---|---|---|---|---|
| R-01 | EMG: incorrect gesture prediction | A user or integrator treats a classifier output as a safe command; a wrong label is passed to an actuator in a future system. No actuator interface exists here. | Unintended movement could cause injury in an unassessed future system. | High if actuator-integrated; no physical hazard pathway in the standalone repository. | Intended-use boundary states that predictions are not actuator commands; grouped holdout is used for offline evaluation. | Unit tests cover model pipeline components. No end-to-end actuator, fault response, human-factors, or clinical validation exists. Any integration requires system-level hazard analysis and independent safeguards. | Open; integration excluded. |
| R-02 | EMG: overstatement of model performance | A short-prefix or repetition-holdout score is presented as whole-dataset or unseen-subject performance. | Poor design decisions, misleading research claims, or inappropriate reliance on the classifier. | Moderate. | Reports state prefix size, exercise, classes, held-out repetitions, and the same-subject limitation. | Reproduce results across prespecified subject-level and repetition-level splits; document uncertainty and class-specific performance before external claims. | Partially controlled; further evaluation open. |
| R-03 | EMG: input or model mismatch | Wrong sampling rate, channel count, exercise, incompatible serialized model, or malformed signal is used for prediction. | Invalid predictions; a future consuming application may act on incorrect output. | Moderate; potentially High after actuator integration. | Signal validation, exercise selection, channel-count validation, and explicit serialized model bundle. | Add version/schema compatibility checks, tests for non-finite or stale model inputs, and a defined invalid-output behavior before deployment. | Partially controlled; deployment controls open. |
| R-04 | EMG: stale or incompatible dependencies/model artifact | A changed library version or replaced model artifact alters predictions without detection. | Reproducibility loss and potentially misleading analysis; physical harm only through an external future integration. | Moderate. | Source and model-training code are version-controlled; model outputs are generated locally. | Pin/lock dependencies, record data and artifact hashes, test reload compatibility, and define a release identifier for each model. | Open. |
| R-05 | Scaffold: threshold interpreted as actual cell death | A reader interprets pixels below a chosen oxygen threshold as observed necrosis or measured viable-cell fraction. | Misleading scientific or engineering decisions about scaffold geometry. | Moderate. | Documentation defines the result as a threshold-based computational indicator and states that cell-death dynamics are not modeled. | Validate parameters and threshold against experimental evidence; use independent review of figures and downstream claims. | Partially controlled; biological validation open. |
| R-06 | Scaffold: idealized channel supply | Constant-concentration channels are interpreted as realistic perfused vessels despite absent flow, pressure loss, transport resistance, and endothelial layers. | A geometry may be selected that performs poorly in fabrication or biological use. | Moderate. | Intended-use and limitations sections explicitly state that channels are fixed-concentration reservoirs and not blood-flow simulations. | Add a justified transport/perfusion model and experimental validation before using results to select a real design. | Partially controlled; model extension open. |
| R-07 | Scaffold: misleading geometry ranking | The search's best score is taken as a physical optimum; the objective rewards viable grid fraction while the smallest channel is tied to grid discretization. | A non-robust or unmanufacturable design could be selected. | Moderate. | Search reports tissue area, hypoxia, viable area, and warns that the result is limited to tested templates; mesh sensitivity is available. | Define fabrication and minimum-feature constraints, use grid-independent physical dimensions, assess mechanical properties, and validate the objective before design decisions. | Partially controlled; engineering constraints open. |
| R-08 | Scaffold: unconverged or numerically biased field | A result is used without checking convergence or despite clipping in the zero-order model. | Incorrect oxygen estimates and misleading comparative conclusions. | Moderate. | Solver returns convergence status; CLI reports it; mesh study fails if a case does not converge; tests verify reference outputs. | Add residual-based verification and compare against an independent sparse solver; characterize clipping and parameter sensitivity. | Partially controlled; numerical cross-check open. |

## Risk-control trace

The requirement IDs and available checks are listed in
[requirements-traceability.md](./requirements-traceability.md). Current
automated checks are software verification evidence only; they do not validate
clinical safety, biological assumptions, intended use, or risk acceptability.

## Open risk-management work

1. Define a specific intended purpose and system boundary before any
   safety-related use.
2. Establish an approved harm-severity and probability scheme and documented
   risk-acceptability criteria for that use.
3. Review hazards and foreseeable sequences with domain experts and intended
   users.
4. Verify each risk control and assess residual risk after controls are
   implemented.
5. Assess overall residual risk and benefit-risk only where the evidence and
   intended purpose justify it.
6. Define post-release monitoring and a process for new hazards, complaints,
   and corrective actions if a real product lifecycle is established.
