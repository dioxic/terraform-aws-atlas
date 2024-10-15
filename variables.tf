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

variable "atlas_private_key" {}

variable "atlas_public_key" {}

variable "client_ssh_key_name" {}

variable "cluster_type" {
  type        = string
  description = "type of cluster, one of REPLICASET, SHARDED, GEOSHARDED"
  default     = "REPLICASET"

  validation {
    condition = contains(["REPLICASET", "SHARDED", "GEOSHARDED"], var.cluster_type)
    error_message = "Allowed values for cluster_type are \"REPLICASET\", \"SHARDED\", or \"GEOSHARDED\"."
  }
}

variable "cluster_map" {
  type = list(object({
    cluster_name = string
    cluster_tier = string
    cluster_type = string
    cluster_disk_size = string
    client_instance_type = string
  }))
}

variable "gh_token" {
  type = string
}

variable "tags" {
  description = "Optional map of tags to set on resources, defaults to empty map."
  type = map(string)
  default = {}
}