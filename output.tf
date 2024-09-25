output "standard_srv" {
  value = mongodbatlas_cluster.main.connection_strings[0].standard_srv
  //value = lookup(mongodbatlas_cluster.cluster-test.connection_strings[0].aws_private_link_srv, aws_vpc_endpoint.ptfe_service.id)
}

output "mongo_uri" {
  value = mongodbatlas_cluster.main.mongo_uri
}

output "mongo_uri_with_options" {
  value = mongodbatlas_cluster.main.mongo_uri_with_options
}

//output "aws_private_link_srv" {
//  value = lookup(mongodbatlas_cluster.main.connection_strings[0].aws_private_link_srv, aws_vpc_endpoint.ptfe_service.id)
//}
//

output "bastion_public_ip" {
 value = aws_instance.bastion.public_ip
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