#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "================================================================"
echo "Agent Sandbox Data Durability Gap Demonstration"
echo "================================================================"
echo ""

echo "=== Step 0: Environment Setup ==="
# [PLACEHOLDER] Install agent-sandbox CRDs and controller from upstream
# e.g., kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/agent-sandbox/main/deploy/install.yaml
echo "Building local agent images and loading into kind cluster..."
docker build -t local/agent-ephemeral:latest ./agent-ephemeral
docker build -t local/agent-durable:latest ./agent-durable
kind load docker-image local/agent-ephemeral:latest
kind load docker-image local/agent-durable:latest

echo ""
echo "=== Step 1: Start both sandboxes, show initial counter ==="
kubectl apply -f pvc-durable.yaml
kubectl apply -f sandbox-ephemeral.yaml
kubectl apply -f sandbox-durable.yaml

echo "Waiting for sandbox pods to become ready..."
sleep 5 # Give controller time to create the pods
kubectl wait --for=condition=Ready pod -l "sandbox=sandbox-ephemeral" --timeout=60s || true
kubectl wait --for=condition=Ready pod -l "sandbox=sandbox-durable" --timeout=60s || true

# Wait for logs to be available
sleep 2

echo "Initial Counter - Ephemeral Agent:"
kubectl logs -l "sandbox=sandbox-ephemeral"
echo "Initial Counter - Durable Agent:"
kubectl logs -l "sandbox=sandbox-durable"

echo ""
echo "=== Step 2: Set both to operatingMode: Suspended ==="
kubectl patch sandbox sandbox-ephemeral --type merge -p '{"spec": {"operatingMode": "Suspended"}}'
kubectl patch sandbox sandbox-durable --type merge -p '{"spec": {"operatingMode": "Suspended"}}'

echo ""
echo "=== Step 3: Confirm both pods are terminated ==="
echo "Waiting for pods to terminate..."
sleep 10
kubectl get pods

echo ""
echo "=== Step 4: Set both back to operatingMode: Running ==="
kubectl patch sandbox sandbox-ephemeral --type merge -p '{"spec": {"operatingMode": "Running"}}'
kubectl patch sandbox sandbox-durable --type merge -p '{"spec": {"operatingMode": "Running"}}'

echo "Waiting for resumed sandbox pods to become ready..."
sleep 5
kubectl wait --for=condition=Ready pod -l "sandbox=sandbox-ephemeral" --timeout=60s || true
kubectl wait --for=condition=Ready pod -l "sandbox=sandbox-durable" --timeout=60s || true
sleep 2

echo ""
echo "=== Step 5: Read the counter from each again ==="
echo "Resumed Counter - Ephemeral Agent (Expected: Reset to 1):"
kubectl logs -l "sandbox=sandbox-ephemeral"

echo "Resumed Counter - Durable Agent (Expected: Incremented to 2):"
kubectl logs -l "sandbox=sandbox-durable"

echo ""
echo "=== Bonus Step 6: CSI Volume Snapshot (Example CSI driver) ==="
echo "Taking a VolumeSnapshot of the durable agent workspace..."

cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: durable-workspace-snapshot
spec:
  volumeSnapshotClassName: example-csi-snapclass
  source:
    persistentVolumeClaimName: agent-durable-workspace
EOF

echo "Waiting for snapshot to be ready to use..."
sleep 5
kubectl wait --for=condition=readytouse volumesnapshot/durable-workspace-snapshot --timeout=60s || true

echo "Deleting original durable Sandbox and PVC entirely..."
kubectl delete -f sandbox-durable.yaml
kubectl delete pvc agent-durable-workspace

echo "Restoring PVC from the VolumeSnapshot..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: agent-durable-workspace
spec:
  storageClassName: default
  dataSource:
    name: durable-workspace-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

echo "Starting durable Sandbox against the restored PVC..."
kubectl apply -f sandbox-durable.yaml

echo "Waiting for restored sandbox pod to become ready..."
sleep 5
kubectl wait --for=condition=Ready pod -l "sandbox=sandbox-durable" --timeout=60s || true
sleep 2

echo "Post-Restore Counter - Durable Agent (Expected: Incremented to 3):"
kubectl logs -l "sandbox=sandbox-durable"

echo ""
echo "=== Demonstration Complete ==="
