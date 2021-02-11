//  with "var.az_priority = true", something like:
//  summary_cidr_blocks = {
//    "us-east-2a" = "172.21.0.0/22"
//    "us-east-2b" = "172.21.4.0/22"
//    "us-east-2c" = "172.21.8.0/22"
//  }
//
//  with "var.az_priority = true", something like:
//  summary_cidr_blocks = {
//    "subnet_a" = "172.21.0.0/23"
//    "subnet_b" = "172.21.2.0/26"
//    "subnet_c" = "172.21.3.0/24"
//  }
output "summary_cidr_blocks" {
  value = module.base_networks.network_cidr_blocks
}

// A list detailing each subnet, including its AZ, CIDR prefix and name.
//  subnets = [
//    {
//      "az" = "us-east-2a"
//      "cidr" = "172.21.0.0/25"
//      "name" = "subnet_a"
//    },
//    {
//      "az" = "us-east-2b"
//      "cidr" = "172.21.0.128/25"
//      "name" = "subnet_a"
//    },
//    {
//      "az" = "us-east-2a"
//      "cidr" = "172.21.1.0/28"
//      "name" = "subnet_b"
//    },
//    {
//      "az" = "us-east-2b"
//      "cidr" = "172.21.1.16/28"
//      "name" = "subnet_b"
//    },
//  ]
output "subnets" {
  value = flatten([ for i in keys(module.base_networks["network_cidr_blocks"]) : [ for j in keys(module.subnet_networks[i]["network_cidr_blocks"]) : {(local.base_network_name) = i, (local.subnet_network_name) = j, cidr = module.subnet_networks[i]["network_cidr_blocks"][j] } ] ])
}
