variable "az_list" {
  description = "list of availability zones for which we'll prepare subnets"
  type        = list(string)
}

variable "az_priority" {
  description = "organize subnets into aggregatable chunks by az. default behavior supports summary by subnet name."
  type        = bool
  default     = false
}

variable "cidr_block" {
  description = "ipv4 summary block from which to take right-sized subnets"
  type        = string
}

variable "ipv6_cidr_block" {
  description = "ipv6 summary block from which to take 64-bit subnets"
  type        = string
  default     = ""
}

variable "name_az_sep" {
  description = "separator character used compose map key in 'subnets_by_name_and_az' output"
  type        = string
  default     = "_"
}

variable "networks" {
  description = "describe subnets we'd like to create"
  type = list(
    object({
      name  = string
      hosts = number
    })
  )
}
