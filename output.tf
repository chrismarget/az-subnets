//  with "var.az_priority = true", something like:
//  summary_cidr_blocks = {
//    "us-east-2a" = "172.21.0.0/22"
//    "us-east-2b" = "172.21.4.0/22"
//    "us-east-2c" = "172.21.8.0/22"
//  }
//
//  with "var.az_priority = false", something like:
//  summary_cidr_blocks = {
//    "subnet_a" = "172.21.0.0/23"
//    "subnet_b" = "172.21.2.0/26"
//    "subnet_c" = "172.21.3.0/24"
//  }
output "summary_cidr_blocks" {
  value = module.aggregate_networks_4.network_cidr_blocks
}

output "ipv6_summary_cidr_blocks" {
  value = module.aggregate_networks_6.network_cidr_blocks
}

// A map detailing each subnet, including its AZ, CIDR prefix and name.
//subnets = {
//  "app-tier_us-east-1a" = {
//    "az" = "us-east-1a"
//    "cidr" = "10.0.2.0/25"
//    "cidr_6" = "2001:db8:0:8::/64"
//    "name" = "app-tier"
//  }
//  "app-tier_us-east-1b" = {
//    "az" = "us-east-1b"
//    "cidr" = "10.0.2.128/25"
//    "cidr_6" = "2001:db8:0:9::/64"
//    "name" = "app-tier"
//  }
//  "app-tier_us-east-1c" = {
//    "az" = "us-east-1c"
//    "cidr" = "10.0.3.0/25"
//    "cidr_6" = "2001:db8:0:a::/64"
//    "name" = "app-tier"
//  }
//  "auth_tier_us-east-1a" = {
//    "az" = "us-east-1a"
//    "cidr" = "10.0.0.0/28"
//    "cidr_6" = "2001:db8::/64"
//    "name" = "auth_tier"
//  }
//  "auth_tier_us-east-1b" = {
//    "az" = "us-east-1b"
//    "cidr" = "10.0.0.16/28"
//    "cidr_6" = "2001:db8:0:1::/64"
//    "name" = "auth_tier"
//  }
//  "auth_tier_us-east-1c" = {
//    "az" = "us-east-1c"
//    "cidr" = "10.0.0.32/28"
//    "cidr_6" = "2001:db8:0:2::/64"
//    "name" = "auth_tier"
//  }
//  "web-tier_us-east-1a" = {
//    "az" = "us-east-1a"
//    "cidr" = "10.0.1.0/26"
//    "cidr_6" = "2001:db8:0:4::/64"
//    "name" = "web-tier"
//  }
//  "web-tier_us-east-1b" = {
//    "az" = "us-east-1b"
//    "cidr" = "10.0.1.64/26"
//    "cidr_6" = "2001:db8:0:5::/64"
//    "name" = "web-tier"
//  }
//  "web-tier_us-east-1c" = {
//    "az" = "us-east-1c"
//    "cidr" = "10.0.1.128/26"
//    "cidr_6" = "2001:db8:0:6::/64"
//    "name" = "web-tier"
//  }
//}
output "subnets" { value = zipmap(local.output_map_keys, local.output_map_elems)}