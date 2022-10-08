
output "ip" {
  value = digitalocean_droplet.nginx_proxy.ipv4_address
}