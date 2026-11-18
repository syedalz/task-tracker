variable "my_ip" {
  description = "My public IP address in CIDR form, allowed to SSH in"
  type        = string
}

variable "image" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}
