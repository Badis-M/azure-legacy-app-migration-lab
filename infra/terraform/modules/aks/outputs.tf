output "name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.main.name
}

output "id" {
  description = "AKS cluster ID."
  value       = azurerm_kubernetes_cluster.main.id
}

output "kubelet_identity_object_id" {
  description = "AKS kubelet identity object ID."
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
