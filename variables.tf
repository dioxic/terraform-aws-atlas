variable "ami_owner" {
  default = "amazon"
}

variable "ami_name" {
  //default = "amzn2-ami-hvm-*-x86_64-gp2"
  default = "al2023-ami-2023.*-x86_64"
}

variable "project_id" {
}

variable "org_id" {
}

variable "cluster_name" {
}

variable "atlas_private_key" {}

variable "atlas_public_key" {}

variable "client_instance_type" {}

variable "client_ssh_key_name" {}

variable "cluster_type" {
  type = string
  description = "type of cluster, one of REPLICASET, SHARDED, GEOSHARDED"
  default = "REPLICASET"

  validation {
    condition     = contains(["REPLICASET", "SHARDED", "GEOSHARDED"], var.cluster_type)
    error_message = "Allowed values for cluster_type are \"REPLICASET\", \"SHARDED\", or \"GEOSHARDED\"."
  }
}

variable "gh_token" {
  type = string
}

variable "cluster_tier" {
  type = string
  default = "M10"
}

variable "tags" {
  description = "Optional map of tags to set on resources, defaults to empty map."
  type        = map(string)
  default     = { }
}