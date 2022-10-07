
provider "docker" {
  host = "ssh://root@${digitalocean_droplet.server.ipv4_address}"
  ssh_opts = ["-o", "StrictHostKeyChecking=no"]
}


resource "docker_container" "nginx_proxy" {
  image = "alpine"
  name  = "alpine"
  command = ["sleep", "infinity"]
}