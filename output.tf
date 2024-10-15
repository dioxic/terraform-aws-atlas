# output "mongo_uri_pl" {
#   value = length(local.connection_strings) > 0 ? local.connection_strings[0] : ""
  # value = mongodbatlas_cluster.main.connection_strings.private_endpoint[0]["srv_connection_string"]
  # value = lookup(mongodbatlas_cluster.main.connection_strings[0].aws_private_link_srv, aws_vpc_endpoint.ptfe_service.id)
# }

output "clusters" {
  value = {
    for k, v in mongodbatlas_cluster.main : k => {
      name = v.name,
      tier = v.provider_instance_size_name,
      private_link_srv = flatten([for cs in v.connection_strings : cs.private_endpoint])
      srv = v.mongo_uri
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