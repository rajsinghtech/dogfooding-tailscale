output "flux_instance" {
  description = "Namespace/name of the FluxInstance"
  value       = "${kubectl_manifest.flux_instance.namespace}/${kubectl_manifest.flux_instance.name}"
}
