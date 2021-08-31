locals {
  // detect whether we've been given an ipv6 block. This test controls output
  // and whether we have to use a stand-in address block.
  enable_v6 = length(var.ipv6_cidr_block) > 0 ? true : false

  // if we weren't supplied an ipv6 block, use the documentation block as a
  // stand-in to keep the other modules happy.
  ipv6_cidr_block = local.enable_v6 == true ? var.ipv6_cidr_block : "2001:DB8::/32"

  // networks * AZs = total subnets
  total_subnets = length(var.networks) * length(var.az_list)

  // AWS reserves 5 addresses per IPv4 subnet
  // https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html#VPC_Sizing
  reserved_host_addrs_per_subnet = 5  // network, router, DNS, future, broadcast
  min_host_bits_per_subnet_4     = 4  // /28 is the minimum subnet size
  min_host_bits_per_subnet_6     = 64 // /64 is the minimum subnet size

  // "network" bit count from var.cidr_block. eg "172.16.0.0/18" would return: 18
  vpc_cidr_bits_4 = parseint(split("/", var.cidr_block)[1], 10)
  // "network" bit count from local.ipv6_cidr_block. eg "2001:DB8::/56" would return: 56
  vpc_cidr_bits_6 = parseint(split("/", local.ipv6_cidr_block)[1], 10)

  // bits required to enumerate availability zones. We'll always use at least 1
  // bit (chop the address space in half) even if only a single AZ is required.
  // This is because of an requirement of the cidrsubnets() function called by
  // the underlying hashicorp/subnets/cidr module. Long story short, there's no
  // point in using this module with a single availability zone.
  az_bits = max(ceil(log(length(var.az_list), 2)), 1)

  // calculate required host bits in each named subnet, based on the specified
  // host count. We take into account AWS overhead, first/last reserved address,
  // and minimum subnet size.
  //
  // Example input data:
  //     min_host_bits_per_subnet_4 = 4
  //     min_host_bits_per_subnet_6 = 64
  //     networks        = [
  //       { name = "web_tier",  hosts = 10 },
  //       { name = "app_tier",  hosts = 28 },
  //       { name = "auth_tier", hosts = 3  },
  //     ]
  //
  //  Result with above data: [  4, 6, 4 ]
  host_bits_by_subnet_4 = [ for i in var.networks : max(ceil(log((i.hosts + local.reserved_host_addrs_per_subnet), 2)), local.min_host_bits_per_subnet_4) ]
  //
  //  Result with above data: [  64, 64, 64 ]
  host_bits_by_subnet_6 = [ for i in var.networks : max(ceil(log((i.hosts + local.reserved_host_addrs_per_subnet), 2)), local.min_host_bits_per_subnet_6) ]

  // A list of extra CIDR bits required to enumerate each AZ as an outer
  // wrapper for all subnets. All will be the same size.
  //
  // For example, with input:
  //
  // az_list         = ["us-east-1a", "us-east-1b"]
  // it returns: [1, 1] (each AZ wrapper summary (2) gets 1/2 of the allocation)
  // it returns: [3, 3, 3, 3, 3] (each AZ wrapper summary (5) gets 1/8 of the allocation)
  network_bits_per_az = [ for i in range(length(var.az_list)) : local.az_bits ]

  // A list of extra CIDR bits required to enumerate each subnet as an outer
  // wrapper for all AZs. These will not be the same size, but will depend on
  // per-subnet host counts.
  //
  // For example, with input:
  //
  //  cidr_block      = "10.0.0.0/8"        // Base bit count of 8
  //  az_list         = ["a", "b", "c"]     // Three AZs, so 2 bits req'd
  //  networks        = [
  //    { name = "web_tier",  hosts = 10 },   // needs 4 host bits per subnet
  //    { name = "app_tier",  hosts = 28 },   // needs 6 host bits per subnet
  //    { name = "auth_tier", hosts = 100 },  // needs 7 host bits per subnet
  //  ]
  //
  // This combination of inputs returns: [18, 16, 15] because:
  //   - 8 bits from "cidr_block", plus...
  //     - 18 bits from this result == 26 bits (the size required for an aggregate block containing "web_tier" for each AZ)
  //     - 16 bits from this result == 24 bits (the size required for an aggregate block containing "app_tier" for each AZ)
  //     - 15 bits from this result == 23 bits (the size required for an aggregate block containing "app_tier" for each AZ)
  network_bits_per_subnet_4 = [ for bits in local.host_bits_by_subnet_4 : (32 - local.vpc_cidr_bits_4 - local.az_bits - bits) ]
  // Same as above, but with:
  //   ipv6_cidr_block = "2001:DB8::/56"
  //
  // This combination of inputs returns: [6, 6, 6] because:
  //   - 56 bits from "cidr_block", plus...
  //     - 6 bits from this result == 62 bits (the size required for an aggregate block containing "web_tier" for each AZ)
  //     - 6 bits from this result == 62 bits (the size required for an aggregate block containing "app_tier" for each AZ)
  //     - 6 bits from this result == 62 bits (the size required for an aggregate block containing "app_tier" for each AZ)
  network_bits_per_subnet_6 = [ for bits in local.host_bits_by_subnet_6 : (128 - local.vpc_cidr_bits_6 - local.az_bits - bits) ]

  // choose the correct summary wrapper bit list from above (either AZ-based or
  // v4/v6 subnet-based) depending on the az_priority variable.
  aggregate_network_bits_4  = var.az_priority ? local.network_bits_per_az : local.network_bits_per_subnet_4
  aggregate_network_bits_6  = var.az_priority ? local.network_bits_per_az : local.network_bits_per_subnet_6

  // choose the correct per-subnet bit list from above (either AZ-based or
  // v4/v6 subnet-based) depending on the az_priority variable.
  subnet_network_bits_4  = var.az_priority ? local.network_bits_per_subnet_4 : local.network_bits_per_az
  subnet_network_bits_6  = var.az_priority ? local.network_bits_per_subnet_6 : local.network_bits_per_az

  // lists of aggregate and subnet names: Each is either the AZ or the network
  // name, depending on az_priority.
  aggregate_network_names = var.az_priority ? var.az_list : var.networks[*].name
  subnet_network_names    = var.az_priority ? var.networks[*].name : var.az_list

  // full length list of aggregates and subnets.
  // For example, With:
  //   - 2 AZs
  //   - 3 networks
  //   - az_priority=false
  //
  //     aggregate_name_list = [ "net1", "net1", "net2", "net2", "net3", "net3" ]
  //     subnet_name_list    = [ "az1",  "az1",  "az1",  "az2",  "az2",  "az2"  ]
  aggregate_name_list = [for i in range(local.total_subnets) : local.aggregate_network_names[floor(i/length(local.subnet_network_names))]]
  subnet_name_list    = [for i in range(local.total_subnets) : element(local.subnet_network_names, i)]

  // Okay, so we made the aggregate/subnet lists above, but which is which?
  output_az_list      = var.az_priority ? local.aggregate_name_list : local.subnet_name_list
  output_network_list = var.az_priority ? local.subnet_name_list : local.aggregate_name_list

  // list of CIDR blocks selected by the hashicorp/subnets/cidr modules.
  output_cidr_4_list  = flatten([ for i in local.aggregate_network_names : [ for j in local.subnet_network_names : module.subnet_networks_4[i]["network_cidr_blocks"][j]]])
  output_cidr_6_list  = flatten([ for i in local.aggregate_network_names : [ for j in local.subnet_network_names : module.subnet_networks_6[i]["network_cidr_blocks"][j]]])

  output_map_keys  = [for i in range(local.total_subnets) : "${local.output_network_list[i]}${var.name_az_sep}${local.output_az_list[i]}"]
  output_map_elems = [for i in range(local.total_subnets) : {
    az        = local.output_az_list[i]
    name      = local.output_network_list[i]
    cidr      = local.output_cidr_4_list[i]
    ipv6_cidr = local.enable_v6 ? local.output_cidr_6_list[i] : ""
  }]
}

// These instances of hashicorp-subnets-cidr (see
// https://github.com/hashicorp/terraform-cidr-subnets)
// chops the provided network summary into pieces. Either evenly-sized
// chunks per availability zone (var.az_priority = true) or per named
// subnet, with each chunk large enough to support an instance of the
// subnet in every availability zone (var.az_priority = false)
module "aggregate_networks_4" {
  source  = "hashicorp/subnets/cidr"
  version = "1.0.0"
  base_cidr_block = var.cidr_block
  networks = [ for i in range(length(local.aggregate_network_bits_4)) : {name = local.aggregate_network_names[i], new_bits = local.aggregate_network_bits_4[i]} ]
}
module "aggregate_networks_6" {
  source  = "hashicorp/subnets/cidr"
  version = "1.0.0"
  base_cidr_block = local.ipv6_cidr_block
  networks = [ for i in range(length(local.aggregate_network_bits_6)) : {name = local.aggregate_network_names[i], new_bits = local.aggregate_network_bits_6[i]} ]
}

// These instances of hashicorp-subnets-cidr (see
// https://github.com/hashicorp/terraform-cidr-subnets)
// chop each aggregate_networks_4/6 into individual subnet-sized pieces.
module "subnet_networks_4" {
  for_each = module.aggregate_networks_4.network_cidr_blocks
  source  = "hashicorp/subnets/cidr"
  version = "1.0.0"
  base_cidr_block = each.value
  networks = [ for i in range(length(local.subnet_network_bits_4)) : {name = local.subnet_network_names[i], new_bits = local.subnet_network_bits_4[i]} ]
}
module "subnet_networks_6" {
  for_each = module.aggregate_networks_6.network_cidr_blocks
  source  = "hashicorp/subnets/cidr"
  version = "1.0.0"
  base_cidr_block = each.value
  networks = [ for i in range(length(local.subnet_network_bits_6)) : {name = local.subnet_network_names[i], new_bits = local.subnet_network_bits_6[i]} ]
}
