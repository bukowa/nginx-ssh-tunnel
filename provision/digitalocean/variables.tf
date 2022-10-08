
variable "volume_path" {
  default = "/certs"
}

variable "server_name" {
  validation {
    error_message = "Invalid server name"
    condition = !startswith(var.server_name, ".")
  }
}

variable "tunnel_host" {
  default = "localhost"
}

variable "tunnel_port" {
  default = "5600"
}