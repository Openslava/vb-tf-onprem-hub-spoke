output "password" {
  sensitive = true
  value     = local.password
}

output "username" {
  value = var.username
}
