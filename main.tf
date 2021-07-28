locals {
  // AWS rserves 5 addresses per IPv4 subnet
  // https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Subnets.html#VPC_Sizing
  reserved_hosts_per_subnet = 5 // network, router, DNS, future, broadcast
  min_host_bits_per_subnet  = 4 // /28 is the minimum subnet size

  // "network" bit count from var.vpc_cidr. eg "172.16.0.0/18" would return: 18
  vpc_cidr_bits = parseint(split("/", var.cidr_block)[1], 10)

  // bits required to enumerate availability zones. We'll always use at least 1
  // bit (chop the address space in half) even if only a single AZ is required.
  // This is because of an requirement of the cidrsubnets() function called by
  // the underlying hashicorp/subnets/cidr module. Long story short, there's no
  // point in using this module with a single availability zone.
  az_bits = max(ceil(log(length(var.az_list), 2)), 1)

  // calculate required host bits for each named subnet, taking into account AWS
  // overhead, first/last address usability, and minimum
  host_bits_by_subnet = [ for i in var.networks : max(ceil(log((i.hosts + local.reserved_hosts_per_subnet), 2)), local.min_host_bits_per_subnet) ]

  // bit count required for each type of outer network container. Only one of
  // these will be used, depending on the value of var.az_priority.
  base_network_bits_by_az     = [ for i in range(length(var.az_list)) : local.az_bits ]
  base_network_bits_by_subnet = [ for bits in local.host_bits_by_subnet : (32 - local.vpc_cidr_bits - local.az_bits - bits) ]

  // list of names / bits of network summary wrappers
  base_network_bits  = var.az_priority ? local.base_network_bits_by_az : local.base_network_bits_by_subnet
  base_network_names = var.az_priority ? var.az_list : var.networks[*].name

  // list of names / bits of inner network specific subnets
  subnet_network_bits  = var.az_priority ? local.base_network_bits_by_subnet : local.base_network_bits_by_az
  subnet_network_names = var.az_priority ? var.networks[*].name : var.az_list

  // output will be by "az" and "subnet" regardless of which is the inner/outer
  // wrapper. set the labels accordingly.
  base_network_name   = var.az_priority ? "az" : "name"
  subnet_network_name = var.az_priority ? "name" : "az"

  // see output.tf
  output_subnets = flatten([ for i in keys(module.base_networks["network_cidr_blocks"]) : [ for j in keys(module.subnet_networks[i]["network_cidr_blocks"]) : {(local.base_network_name) = i, (local.subnet_network_name) = j, cidr = module.subnet_networks[i]["network_cidr_blocks"][j] } ] ])
  output_subnets_by_name_and_az = zipmap([ for i in local.output_subnets : "${i["name"]}${var.name_az_sep}${i["az"]}"], local.output_subnets)
}

// This instance of hashicorp-subnets-cidr (see
// https://github.com/hashicorp/terraform-cidr-subnets)
// chops the provided network summary into pieces. Either evenly-sized
// chunks per availability zone (var.az_priority = true) or per named
// subnet, with each chunk large enough to support an instance of the
// subnet in every availability zone (var.az_priority = false)
module "base_networks" {
  source  = "hashicorp/subnets/cidr"
  version = "1.0.0"
  base_cidr_block = var.cidr_block
  networks = [ for i in range(length(local.base_network_bits)) : {name = local.base_network_names[i], new_bits = local.base_network_bits[i]} ]
}

// These instances of hashicorp-subnets-cidr (see
// https://github.com/hashicorp/terraform-cidr-subnets)
// chop each output.summary_cidr_block individual subnet-sised peices.
module "subnet_networks" {
  for_each = module.base_networks.network_cidr_blocks
  source  = "hashicorp/subnets/cidr"
  version = "1.0.0"
  base_cidr_block = each.value
  networks = [ for i in range(length(local.subnet_network_bits)) : {name = local.subnet_network_names[i], new_bits = local.subnet_network_bits[i]} ]
}
