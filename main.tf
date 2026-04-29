provider "mongodbatlas" {
  public_key  = var.atlas_public_key
  private_key = var.atlas_private_key
}

provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = var.tags
  }
}

data "aws_region" "current" {}

data "aws_ami" "base" {
  most_recent = true
  owners = [var.ami_owner]

  filter {
    name = "name"
    values = [var.ami_name]
  }

  filter {
    name = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name = "default-for-az"
    values = ["true"]
  }
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "http" "my_public_ip" {
  url = "https://api.ipify.org?format=json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  vpc_id      = data.aws_vpc.default.id
  subnet_ids = tolist(data.aws_subnets.default.ids)
  ifconfig = jsondecode(data.http.my_public_ip.response_body)
  cluster_map = {for v in var.clusters : v.cluster_name => v}
  client_map  = {
    for v in var.clients : v.client_name => merge(v, {
      uri       = join("", [var.uri_prefix, v.client_name, var.uri_suffix])
      stats_uri = join("", [var.uri_prefix, "stats", var.uri_suffix])
    })
  }
  # private_endpoints  = coalesce(mongodbatlas_advanced_cluster.main.connection_strings.private_endpoint, [])
  # connection_strings = [
  #   for pe in local.private_endpoints : pe.srv_connection_string
  #   if contains([for e in pe.endpoints : e.endpoint_id], local.endpoint_service_id)
  # ]
  # cluster_private_srv = {
  #   for k, v in mongodbatlas_advanced_cluster.main : k =>
  #     length(v.connection_strings) > 0 ? length(v.connection_strings[0].private_endpoint) > 0 ?
  #     v.connection_strings[0].private_endpoint[0]["srv_connection_string"] : "" : ""
  # }
  # cluster_pl_srv = { for k, v in local.cluster_private_endpoints : k =>
  #   [ for pe in v : v.srv_connection_string if contains([for e in pe.endpoints : e.endpoint_id], aws_vpc_endpoint.ptfe_service.id) ]
  # }
  # connection_strings = [
  #   for pe in local.private_endpoints : pe.srv_connection_string
  #   if contains([for e in pe.endpoints : e.endpoint_id], aws_vpc_endpoint.ptfe_service.id)
  # ]
}

data "cloudinit_config" "config" {
  for_each      = local.client_map
  base64_encode = true
  gzip          = true
  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/scripts/bootstrap.sh", {
      gh_token  = var.gh_token
      uri       = local.client_map[each.key]["uri"]
      stats_uri = local.client_map[each.key]["stats_uri"]
    })
  }
}

# ----------------------- Security Groups ------------------------------

resource "aws_security_group" "main" {
  name_prefix = "atlas-sg-"
  vpc_id      = local.vpc_id
  tags        = var.tags
}

resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  description       = "SSH"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.main.id
}

# ports on the Atlas PL endpoint start at 1024
resource "aws_security_group_rule" "atlas-pl" {
  type              = "ingress"
  from_port         = 1024
  to_port           = 2024
  protocol          = "tcp"
  description       = "SSH"
  self              = true
  security_group_id = aws_security_group.main.id
}

resource "aws_security_group_rule" "everything" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  description       = "Everything"
  cidr_blocks = ["${local.ifconfig["ip"]}/32"]
  security_group_id = aws_security_group.main.id
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.main.id
}

# -------------------- Private Link ----------------------

resource "mongodbatlas_privatelink_endpoint" "main" {
  project_id    = var.project_id
  provider_name = "AWS"
  region        = data.aws_region.current.name
}

resource "aws_vpc_endpoint" "ptfe_service" {
  vpc_id            = local.vpc_id
  service_name      = mongodbatlas_privatelink_endpoint.main.endpoint_service_name
  vpc_endpoint_type = "Interface"
  subnet_ids        = local.subnet_ids
  security_group_ids = [aws_security_group.main.id]
  # tags              = var.tags
}

resource "mongodbatlas_privatelink_endpoint_service" "main" {
  project_id          = mongodbatlas_privatelink_endpoint.main.project_id
  private_link_id     = mongodbatlas_privatelink_endpoint.main.id
  endpoint_service_id = aws_vpc_endpoint.ptfe_service.id
  provider_name       = "AWS"
}

# ------------------ Atlas Access List ------------------------------

resource "mongodbatlas_project_ip_access_list" "test" {
  project_id = var.project_id
  ip_address = local.ifconfig["ip"]
  comment    = "terraform"
}

# ------------------ Atlas Database User ----------------------------

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "mongodbatlas_database_user" "root" {
  username           = "tf"
  password           = random_password.password.result
  project_id         = var.project_id
  auth_database_name = "admin"

  roles {
    role_name     = "atlasAdmin"
    database_name = "admin"
  }
}

# resource "mongodbatlas_auditing" "test" {
#  project_id                  = var.project_id
#  audit_filter                = file("${path.module}/config/audit-filter.json")
#  audit_authorization_success = true
#  enabled                     = true
# }

# resource "mongodbatlas_encryption_at_rest" "main" {
#  project_id = var.project_id
#
#  aws_kms = {
#    enabled                = true
#    access_key_id          = "AKIAIOSFODNN7EXAMPLE"
#    secret_access_key      = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
#    customer_master_key_id = "030gce02-586d-48d2-a966-05ea954fde0g"
#    region                 = "US_EAST_1"
#  }
# }

# --------------- AWS EC2 ---------------------

resource "tls_private_key" "generated" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name_prefix = var.client_ssh_key_name
  public_key = tls_private_key.generated.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.generated.private_key_pem
  filename        = "${path.module}/${var.client_ssh_key_name}.pem"
  file_permission = "0600"
}

resource "aws_instance" "client" {
  for_each      = local.client_map
  ami           = data.aws_ami.base.id
  instance_type = each.value["client_instance_type"]
  key_name      = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id = local.subnet_ids[0]

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }

  tags = { "Name" = "client-${each.value["client_name"]}" }

  user_data = data.cloudinit_config.config[each.key].rendered
  //user_data = data.template_cloudinit_config.mongodb[each.key].rendered
}

resource "mongodbatlas_advanced_cluster" "main" {
  for_each     = local.cluster_map
  depends_on = [mongodbatlas_privatelink_endpoint_service.main]
  project_id   = var.project_id
  name         = each.key
  cluster_type = each.value["cluster_type"]

  replication_specs = [
    {
      region_configs = [
        {
          electable_specs = {
            instance_size        = each.value["cluster_tier"]
            node_count           = 3
            disk_size_gb         = each.value["cluster_disk_size"]
            provider_disk_iops   = each.value["cluster_disk_iops"]
            provider_volume_type = each.value["cluster_volume_type"]
          }
          auto_scaling = {
            compute_enabled = false
            disk_gb_enabled = true
          }
          provider_name = "AWS"
          priority      = 7
          region_name   = "EU_WEST_1"
        }
      ]
    }
  ]

  backup_enabled = each.value["cluster_backup"]
  mongo_db_major_version = each.value["cluster_version"]
  paused                 = each.value["cluster_paused"]
}