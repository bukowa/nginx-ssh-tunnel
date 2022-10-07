
data "digitalocean_ssh_key" "default" {
  name = "BUKBUK"
}

resource "digitalocean_droplet" "server" {
  image  = "docker-20-04"
  name   = "proxy-server"
  region = "fra1"
  size   = "s-1vcpu-1gb"
  ssh_keys = [data.digitalocean_ssh_key.default.fingerprint]

  connection {
    type = "ssh"
    user = "root"
    host = self.ipv4_address
    agent = true
#    private_key = file(pathexpand("~/.ssh/id_rsa"))
  }

  provisioner "remote-exec" {
    inline = [
      "set -o errexit",
      "ufw --force enable"
    ]
  }
}
