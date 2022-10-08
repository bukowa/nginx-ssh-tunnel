
data "digitalocean_ssh_key" "ssh" {
  name = "BUKBUK"
}

resource "digitalocean_droplet" "nginx_proxy" {
  image  = "docker-20-04"
  name   = "nginx-ssh-tunnel"
  region = "fra1"
  size   = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.ssh.fingerprint]

  connection {
    type = "ssh"
    host = digitalocean_droplet.nginx_proxy.ipv4_address
    user = "root"
  }

  provisioner "remote-exec" {
    inline = [
      "ufw --force reset",
      "ufw default deny incoming",
      "ufw default allow outgoing",
      "ufw allow ssh",
      "ufw allow http",
      " ufw allow https",
      "ufw --force enable",
      "mkdir -p ${var.volume_path}"
    ]
  }
}


locals {
  server_slice = split(".", var.server_name)
  len = length(local.server_slice)
  domain = join(".", slice(local.server_slice, local.len - 2, local.len))
  record_name = (local.len == 2) ? "@" : join(".", slice(local.server_slice, 0, local.len - 2))
}

data "digitalocean_domain" "domain" {
  name = local.domain
}

resource "digitalocean_record" "domain" {
  domain = data.digitalocean_domain.domain.id
  type = "A"
  name = local.record_name
  value  = digitalocean_droplet.nginx_proxy.ipv4_address
}

provider "docker" {
  host = "ssh://root@${digitalocean_droplet.nginx_proxy.ipv4_address}:22"
  ssh_opts = ["-o", "StrictHostKeyChecking=no"]
}

resource "docker_container" "nginx_proxy" {
  image = "quay.io/k8start/nginx-ssh-tunnel:0.1.0"
  name  = "http-proxy"
  restart = "always"

  network_mode = "host"

  volumes {
    container_path = "/certs"
    host_path = var.volume_path
  }

  env = [
    "SERVER=${var.server_name}",
    "TUNNEL_PORT=${var.tunnel_port}",
    "TUNNEL_HOST=${var.tunnel_host}",
  ]

}
