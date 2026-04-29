# output "mongo_uri_pl" {
#   value = length(local.connection_strings) > 0 ? local.connection_strings[0] : ""
  # value = mongodbatlas_cluster.main.connection_strings.private_endpoint[0]["srv_connection_string"]
  # value = lookup(mongodbatlas_cluster.main.connection_strings[0].aws_private_link_srv, aws_vpc_endpoint.ptfe_service.id)
# }

output "clusters" {
  value = {
    for k, v in mongodbatlas_advanced_cluster.main : k => {
      name = v.name,
      tier = v.replication_specs[0].region_configs[0].electable_specs.instance_size,
      # private_link_srv = local.cluster_private_srv[k]
      # private_link_srv = flatten([for cs in v.connection_strings : cs.private_endpoint])
      # private_link_srv = v.connection_strings[0]["private_endpoint"]["srv_connection_string"]
      private_srv = length(v.connection_strings.private_endpoint) == 1 ? v.connection_strings.private_endpoint[0].srv_connection_string : ""
      standard_srv = v.connection_strings.standard_srv
    }
  }
}

output "clients" {
  value = {
    for k,v in aws_instance.client : k => {
      public_ip = v.public_ip
      instance_type = v.instance_type
    }
  }
}

# output "client_public_ip" {
#   value = aws_instance.client.public_ip
# }

# output "atlas_username" {
#   value = mongodbatlas_database_user.root.username
# }

//output "apiKeyBash" {
//  value = local.apiKeyBash
//}

output "vpc_id" {
  value = data.aws_vpc.default.id
}