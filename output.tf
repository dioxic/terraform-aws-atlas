output "mongo_uri_srv" {
  value = mongodbatlas_cluster.main4.connection_strings[0].standard_srv
  //value = lookup(mongodbatlas_cluster.cluster-test.connection_strings[0].aws_private_link_srv, aws_vpc_endpoint.ptfe_service.id)
}

output "mongo_uri" {
  value = mongodbatlas_cluster.main4.mongo_uri
}

output "mongo_uri_with_options" {
  value = mongodbatlas_cluster.main4.mongo_uri_with_options
}

output "mongo_uri_pl" {
  value = length(local.connection_strings) > 0 ? local.connection_strings[0] : ""
  # value = mongodbatlas_cluster.main.connection_strings.private_endpoint[0]["srv_connection_string"]
  # value = lookup(mongodbatlas_cluster.main.connection_strings[0].aws_private_link_srv, aws_vpc_endpoint.ptfe_service.id)
}

# output "client_public_ip" {
#   value = aws_instance.client.public_ip
# }
#
# output "client2_public_ip" {
#   value = aws_instance.client2.public_ip
# }

# output "client3_public_ip" {
#   value = aws_instance.client3.public_ip
# }

output "client4_public_ip" {
  value = aws_instance.client4.public_ip
}

# output "atlas_username" {
#   value = mongodbatlas_database_user.root.username
# }

//output "apiKeyBash" {
//  value = local.apiKeyBash
//}

output "vpc_id" {
  value = data.aws_vpc.default.id
}