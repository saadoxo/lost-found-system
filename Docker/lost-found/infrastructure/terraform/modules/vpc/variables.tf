variable "project"              { type = string }
variable "environment"           { type = string }
variable "cidr_block"            { type = string }
variable "availability_zones"    { type = list(string) }
variable "public_subnet_cidrs"   { type = list(string) }
variable "private_subnet_cidrs"  { type = list(string) }
variable "common_tags"           { type = map(string) }
