## az-subnets

#### A terraform module for laying out IP subnets

This module is *mostly* a wrapper for [Martin Atkins](https://github.com/apparentlymart)
/ Hashicorp's
[terraform-cidr-subnets](https://github.com/hashicorp/terraform-cidr-subnets)
with the following benefits:
- It's a little easier to use (`new_bits` is a brain-bender for me because it's
based on the VPC CIDR allocation size, rather than the desired subnet outcome.)
- IPv4 subnets of varying sizes get packed reasonably across multiple
availability zones according to a user-selectable aggregation/summarization
strategy.

No resources are created by this module. Rather, it provides outputs appropriate
for use in something like an `aws_subnet` resource block's `for_each`
meta-argument. The number of subnets planned by this module is the product of
the counts of availability zones and named networks.

#### Example usage

````
module "subnets" {
  source     = "github.com/chrismarget/az-subnets"
  az_list    = ["us-east-2a", "us-east-2b"]
  cidr_block = "172.21.0.0/20"
  networks   = [
                 { name = "web_tier",  hosts = 10 },
                 { name = "app_tier",  hosts = 28 },
                 { name = "auth_tier", hosts = 3  },
               ]
}
````
With these inputs the module begins by slicing three *minimally sized* chunks
(`summary_cidr_blocks`) from the provided `cidr_block`. Each chunk is just big
enough to hold all instances (one per availability zone) of each network. The
result appears in the `summary_cidr_blocks` output:
```
summary_cidr_blocks = {
  "app_tier" = "172.21.0.128/25"
  "auth_tier" = "172.21.1.0/28"
  "web_tier" = "172.21.0.0/27"
}
```
The `web_tier` network indicated a requirement for 10 hosts, so each instance
will fit in a /28 (11 usable addresses). Because we specified two availability
zones, a /27 (two /28s) was allocated for `web_tier`.

The `app_tier` network indicated a requirement for 28 hosts, which only fits in
an AWS /26 (64 hosts) due to AWS reserving 5 addresses per subnet. Accordingly,
a /25 (two /26s) was allocated for `app_tier`

Each member of `summary_cidr_blocks` is further subdivided into individual subnets,
available via the `subnets` output:

```
subnets = [
  {
    "az" = "us-east-2a"
    "cidr" = "172.21.0.128/26"
    "name" = "app_tier"
  },
  {
    "az" = "us-east-2b"
    "cidr" = "172.21.0.192/26"
    "name" = "app_tier"
  },
  {
    "az" = "us-east-2a"
    "cidr" = "172.21.1.0/29"
    "name" = "auth_tier"
  },
  {
    "az" = "us-east-2b"
    "cidr" = "172.21.1.8/29"
    "name" = "auth_tier"
  },
  {
    "az" = "us-east-2a"
    "cidr" = "172.21.0.0/28"
    "name" = "web_tier"
  },
  {
    "az" = "us-east-2b"
    "cidr" = "172.21.0.16/28"
    "name" = "web_tier"
  },
]

```
This is an example of the default subnet packing behavior which seeks to place
all instances of related subnets into adjacent address space. This placement
strategy simplifies writing policy expressions on routers/firewalls/etc... which
might benefit from being able to refer to all instances of a particular service
with a single expression. See the `az_priority` switch to change this behavior.

#### `az_priority` packing mode

The packing behavior changes when the `az_priority` variable is set to `true`
(default: `false`). In that case, the `summary_cidr_blocks` now represent
availability zones, rather than per-name network aggregates which span
availability zones. Each zone gets an evenly divided (subject to CIDR
powers-of-two limitations) slice of the supplied `cidr_block`. Individual
subnets are then densely packed within these per-az allocations:

Input:
```
module "subnets" {
  source      = "github.com/chrismarget/az-subnets"
  az_list     = ["us-east-2a", "us-east-2b"]
  az_priority = true
  cidr_block  = "172.21.0.0/20"
  networks    = [
                  { name = "web_tier",  hosts = 10 },
                  { name = "app_tier",  hosts = 28 },
                  { name = "auth_tier", hosts = 3  },
                ]
}
```
Outputs:
```
summary_cidr_blocks = {
  "us-east-2a" = "172.21.0.0/21"
  "us-east-2b" = "172.21.8.0/21"
}
```
```
subnets = [
  {
    "az" = "us-east-2a"
    "cidr" = "172.21.0.64/26"
    "name" = "app_tier"
  },
  {
    "az" = "us-east-2a"
    "cidr" = "172.21.0.128/29"
    "name" = "auth_tier"
  },
  {
    "az" = "us-east-2a"
    "cidr" = "172.21.0.0/28"
    "name" = "web_tier"
  },
  {
    "az" = "us-east-2b"
    "cidr" = "172.21.8.64/26"
    "name" = "app_tier"
  },
  {
    "az" = "us-east-2b"
    "cidr" = "172.21.8.128/29"
    "name" = "auth_tier"
  },
  {
    "az" = "us-east-2b"
    "cidr" = "172.21.8.0/28"
    "name" = "web_tier"
  },
]
```
#### Changing networks later
Because we're relying on the
[terraform-cidr-subnets](https://github.com/hashicorp/terraform-cidr-subnets)
module, the same
[rules](https://github.com/hashicorp/terraform-cidr-subnets#changing-networks-later)
about changing subnet allocations apply: The changes can be very disruptive
because any subnet that's resized or moved will be replaced. Adding new subnets
should be safe. Removing subnets, changing subnet sizes, and adding/removing
availability zones and changing the aggregation strategy may result in
disruptive changes. Rather than removing a subnet or availability zone, setting
its name to `null` will cause it to be omitted from the output without
reshuffling other allocations.
