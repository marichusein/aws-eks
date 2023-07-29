variable "db" {
  description = "PostgreSQL database configuration"
  type = object({
    allocated_storage = number
    engine            = string
    engine_version    = string
    instance_class    = string
    name              = string
    username          = string
    password          = string
  })
  //sensitive = true
}

variable "resource_name" {
  description = "Generic part of the name for the resources"
  type        = string
  default     = "huso"
}

data "aws_availability_zones" "available" {
}

output "availability_zones" {
  value = data.aws_availability_zones.available.names
}