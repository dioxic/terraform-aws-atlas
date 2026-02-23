variable "ami_owner" {
  default = "amazon"
}

variable "ami_name" {
  //default = "amzn2-ami-hvm-*-x86_64-gp2"
  default = "al2023-ami-2023.*-x86_64"
}

variable "project_id" {}

variable "org_id" {}

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

variable "clusters" {
  type = list(object({
    cluster_name         = string
    cluster_paused       = bool
    cluster_backup       = bool
    cluster_tier         = string
    cluster_type         = string
    cluster_num_shards   = number
    cluster_version      = string
    cluster_volume_type  = optional(string)
    cluster_disk_size    = optional(number)
    cluster_disk_iops    = optional(number)
  }))
}

variable "clients" {
  type = list(object({
    client_name         = string
    client_instance_type = string
  }))
}

variable "gh_token" {
  type = string
}

variable "uri_prefix" {
  type = string
}

variable "uri_suffix" {
  type = string
}

variable "tags" {
  description = "Optional map of tags to set on resources, defaults to empty map."
  type = map(string)
  default = {}
}