variable "environment" {
  description = "Split-DNS domain prefix: <environment>.svc.cluster.local is rewritten to svc.cluster.local"
  type        = string
}

variable "upstream" {
  description = "Resolver for the rewritten names, normally the kube-dns ClusterIP"
  type        = string
}

variable "namespace" {
  description = "Namespace for the split-DNS CoreDNS"
  type        = string
  default     = "kube-system"
}

variable "image" {
  description = "CoreDNS image"
  type        = string
  default     = "docker.io/coredns/coredns:1.14.7@sha256:7efd3c635b03efd68c4e8398fc45f0d993d0e9ab016f72c1cefb0fd6d01aa286"
}

variable "replicas" {
  description = "CoreDNS replicas"
  type        = number
  default     = 2
}
