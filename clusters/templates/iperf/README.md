# Kubernetes Cross-Cluster Network Performance Testing with iperf3 and Tailscale

This directory contains Kubernetes manifests for setting up iperf3 network performance testing between two Kubernetes clusters using Tailscale.

## Setup

### Prerequisites
- Two Kubernetes clusters with the Tailscale operator installed
- Both clusters are part of the same Tailscale tailnet

### Deployment

1. Deploy the iperf server in the first cluster:
   ```
   kubectl apply -k iperf/server
   ```

2. Note the Tailscale FQDN of the server service:
   ```
   kubectl get svc iperf-server
   ```
   The service should show an External-IP once Tailscale has provisioned it.
   
3. Update the egress service in `iperf/client/egress-service.yaml` with the correct FQDN:
   ```yaml
   annotations:
     tailscale.com/tailnet-fqdn: "default-iperf-server.tail8eff9.ts.net"  # Replace with your actual FQDN
   ```

4. Deploy the iperf client in the second cluster:
   ```
   kubectl apply -k iperf/client
   ```

## Running Performance Tests

### Using Direct Tailscale IP

1. Determine the Tailscale IP address of your iperf-server:
   ```
   kubectl get svc iperf-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
   ```

2. Connect to the iperf client pod in the second cluster:
   ```
   kubectl exec -it $(kubectl get pod -l app=iperf-client -o jsonpath='{.items[0].metadata.name}') -- sh
   ```

3. Run the iperf test (replace SERVER_IP with the Tailscale IP from step 1):
   ```
   iperf3 -c SERVER_IP -p 5201 -t 30
   ```

### Using Tailscale Egress Service

1. Connect to the iperf client pod:
   ```
   kubectl exec -it $(kubectl get pod -l app=iperf-client -o jsonpath='{.items[0].metadata.name}') -- sh
   ```

2. Run the iperf test using the service name:
   ```
   iperf3 -c iperf-server-egress -p 5201 -t 30
   ```
   
   For more detailed results:
   ```
   iperf3 -c iperf-server-egress -p 5201 -t 30 -J
   ```
   
   For bidirectional test:
   ```
   iperf3 -c iperf-server-egress -p 5201 -t 30 -R
   ```

## Cleanup

1. Delete the iperf server in the first cluster:
   ```
   kubectl delete -k iperf/server
   ```

2. Delete the iperf client in the second cluster:
   ```
   kubectl delete -k iperf/client
   ``` 