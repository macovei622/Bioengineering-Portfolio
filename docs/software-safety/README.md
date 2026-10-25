# Software Safety and Lifecycle Documentation

## Purpose and status

This is a proportionate, educational documentation package for the Python
implementations of Projects 1 and 3 in this repository. Its structure is
informed by risk-management concepts in ISO 14971 and software lifecycle
concepts in IEC 62304. It is not a claim of conformity, certification,
regulatory approval, or medical-device readiness.

The projects are research/educational prototypes. Neither is specified,
verified, or validated for diagnosis, treatment, patient management, or direct
control of a medical device. Project 1 produces offline evaluation metrics and
gesture predictions; Project 3 produces numerical oxygen fields and geometry
comparisons. Project 2 is outside this package's scope.

## Documents

- [System scope and intended use](./system-scope.md) — users, inputs, outputs,
  boundaries, and excluded use.
- [Preliminary risk-management file](./risk-management.md) — hazards,
  foreseeable sequences, harms, controls, verification evidence, and open
  actions.
- [Software lifecycle plan](./software-lifecycle-plan.md) — lightweight
  development, maintenance, and release activities.
- [Requirements and traceability](./requirements-traceability.md) — identified
  software requirements, implementation locations, and verification links.
- [Verification report](./verification-report.md) — available automated test
  evidence and known verification gaps.
- [Configuration management](./configuration-management.md) — source,
  dependencies, data, model, and release identification practices.

## How to interpret the risk records

The risk register is an initial engineering screen, not a completed risk
analysis. Severity and likelihood descriptions are qualitative prompts for
review; no risk-acceptability criteria, approved risk policy, formal residual
risk decisions, or benefit-risk analysis have been established. “Control
implemented” means only that a corresponding prototype safeguard or
documentation statement exists; it does not mean the risk is closed.

Before any use that could influence a real person or a medical-device
controller, the intended purpose, stakeholders, hazards, risk policy,
verification evidence, and applicable regulatory requirements would need to be
reassessed by the responsible organization and qualified personnel.

## Baseline

The initial documentation baseline is associated with repository revision
`be95405` (English repository update, 2026-10-25). The package itself is a
subsequent documentation change. Revisions should update the baseline and
evidence links when software, data, intended use, or assumptions change.
