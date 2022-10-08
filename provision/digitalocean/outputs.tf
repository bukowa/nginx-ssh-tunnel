
output "ip" {
  value = digitalocean_droplet.nginx_proxy.ipv4_address
}

output "tunnel_port" {
  value = var.tunnel_port
}
