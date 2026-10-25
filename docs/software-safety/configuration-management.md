# Configuration and Change Management

## Source baseline

All authoritative source changes are tracked in Git. The software and
test-evidence baseline referenced by this package is repository revision
`be95405`, which predates the package. Update this file when defining a later
release baseline.

Each release or result intended for external use should identify:

- Git commit ID and release tag, if any;
- Python version, operating system, and installed dependency versions;
- project and command-line options used;
- input-data source, ordered part names, and cryptographic hash where
  practical;
- model artifact path/hash, training configuration, and split seed;
- generated report/figure paths and the software revision that produced them.

## Dependencies

`requirements-python.txt` specifies minimum dependency versions but is not a
fully resolved lock file. Results can vary across dependency versions and
platforms. Before a reproducible or safety-relevant release, resolve and pin
the full environment, review dependency provenance and licenses, and verify
the supported configuration.

## Data and generated artifacts

The checked-in NinaPro CSV parts are input data, not generated software
outputs. Preserve their ordering and verify data integrity before relying on
results. A production data pipeline would need controlled provenance,
integrity, access, retention, and privacy procedures appropriate to its use.

Generated model bundles, confusion matrices, and run-specific outputs are
ignored by Git. They are not release evidence unless deliberately archived
with their source revision, configuration, dataset identity, and model hash.
Do not replace a tracked reference figure silently; update its provenance and
documentation.

## Change control

For a change to source, model assumptions, dependencies, input schema,
requirements, risk controls, or intended use:

1. Create or reference an issue describing the change and motivation.
2. Identify affected requirement IDs, risk entries, outputs, and dependent
   software items.
3. Update requirements, design/assumptions, and risk records as needed.
4. Implement the change in a reviewable commit.
5. Run and record relevant regression tests; add tests for changed behavior.
6. Review generated metrics/figures for unexpected changes.
7. Update documentation and release identification.

Changes that could affect model behavior or safety controls require explicit
impact review; a passing test suite alone is insufficient.

## Defect handling and maintenance

Record defects with reproducible steps, affected versions, impact, and links to
requirements and risks. Triage model-output changes, data-parsing issues,
solver non-convergence, dependency vulnerabilities, and documentation errors.
Document whether each issue is corrected, deferred with rationale, or outside
the declared educational scope.

## Release and rollback

Use a tagged Git revision for a named release. Preserve the previous revision
and avoid overwriting model artifacts without recording a new identity.
Rollback means returning to a previously identified source and compatible
model/data configuration; it is not guaranteed merely by restoring Python
source when dependencies or model artifacts have changed.
