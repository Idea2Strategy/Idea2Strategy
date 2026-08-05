# Backtest contract registry alignment proposal

Status: proposal only. This file does not change the protected canonical
contract or registry.

## Observed defect

At root `676aa939e364917f08b0d21c298df3c9cf4445b1`,
`contracts/data/backtest-execution.v1.md` declares revision `3` and includes
`quality.reproducibility`, while its `contracts/registry.yaml` entry still
declares revision `2`, omits that reference, and pins the older fingerprint
`sha256:068cc5203b616d0b1db78f4eaa16ade3cc6a00ef805cf894fc00dc1ec3e0c144`.

Consequently, `stackcord context audit --json` reports both
`contract.backtest.execution.v1.fingerprint-drift` and
`contract.backtest.execution.v1.metadata-mismatch`; eight dependent context
entries become stale.

## Authority-owned canonical change

After a fresh provider-backed governance check approves the exact protected
fingerprint, the product authority should update only the
`contract.backtest.execution.v1` registry entry as follows:

```diff
-    revision: 2
+    revision: 3
...
       - quality.failure-safety
-    fingerprint: sha256:068cc5203b616d0b1db78f4eaa16ade3cc6a00ef805cf894fc00dc1ec3e0c144
+      - quality.reproducibility
+    fingerprint: sha256:5b3f6397acaa1767c36dd5fa097f9fd34be2dc37891791425ea66d10fb8287e5
```

The fingerprint above is the SHA-256 of the exact current UTF-8 contract file.
The authority-owned adoption should also add a regression test that reads the
contract, computes its SHA-256, and asserts that registry revision, refs, and
fingerprint match. That prevents a later protected contract edit from passing
root CI with a stale registry entry.

## Required verification

1. `stackcord governance check --json` reports an approved configured product
   authority for the exact repository head and protected fingerprint.
2. Apply the canonical registry change in the authority-owned PR.
3. Run `stackcord context audit --json`; it must report zero stale and zero
   unknown entries.
4. Run the root schema/coordination and full CI suites.

