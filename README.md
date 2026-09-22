# Agent Sandbox State Durability Proof of Concept

This repository provides a standalone, reproducible demonstration of a data durability gap in the `kubernetes-sigs/agent-sandbox` project's `Suspended` operating mode.

## The Gap

When an Agent Sandbox transitions to `operatingMode: Suspended`, the underlying Pod is often terminated by the sandbox controller to release node resources, to be recreated when the mode changes back to `Running`. 

**The finding is this:** Suspended mode's data durability is entirely dependent on where the developer chooses to write state, and nothing in the API or docs currently makes that explicit or enforced.

- State written to a Sandbox's **ephemeral pod filesystem** (e.g. standard local paths within the container) is **lost entirely** on suspend/resume.
- State written to a mounted **PersistentVolumeClaim (PVC)** survives the suspend/resume cycle successfully.

Without API-level enforcement or clear documentation, users trusting `Suspended` to preserve their agent's session state will silently lose data if their agent framework defaults to writing to the ephemeral container root.

## Contents

- `agent-ephemeral/`: A minimal toy agent that stores state on its ephemeral filesystem.
- `agent-durable/`: The exact same agent logic, but meant to be deployed with a PVC mount at the state path.
- `sandbox-ephemeral.yaml` / `sandbox-durable.yaml`: Sandbox CRD definitions showcasing both patterns.
- `demo.sh`: An automated demonstration script that provisions both sandboxes, suspends them, resumes them, and verifies the resulting state.

## Prerequisites

- A local `kind` cluster.
- `agent-sandbox` CRDs and controller installed.
- (Optional for bonus step) A cluster provisioned with a CSI driver that supports Kubernetes VolumeSnapshots.

## Usage

Run the demonstration script:

```bash
./demo.sh
```

## License

MIT License. See `LICENSE` for details.
