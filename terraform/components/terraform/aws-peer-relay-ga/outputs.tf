output "clients" {
  description = "Client VMs, consumed by files/measure.sh"
  value = {
    for k, v in google_compute_instance.client : k => {
      hostname = format("%s-client-%s", local.name, k)
    }
  }
}

output "message" {
  description = "How to reach the test setup"
  value = format(
    "Relay mode: %s\nRelay endpoints advertised in addition to discovered ones: %s\nRun the measurement from a device on the tailnet:\nfiles/measure.sh %s <label> <out-dir>\nSSH to a client over Tailscale SSH:\n%s",
    var.relay_mode,
    length(local.ga_endpoints) > 0 ? join(", ", local.ga_endpoints) : "none",
    local.name,
    join("\n", [for k in keys(var.clients) : format("ssh root@%s-client-%s", local.name, k)])
  )
}
