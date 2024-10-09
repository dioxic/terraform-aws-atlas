provider "mongodbatlas" {
  public_key  = var.atlas_public_key
  private_key = var.atlas_private_key
}

provider "aws" {
  region = "eu-west-1"
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

data "cloudinit_config" "config" {
  base64_encode = true
  gzip          = true
  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/scripts/bootstrap.sh", {
      gh_token = var.gh_token
      uri = length(local.connection_strings) > 0 ? local.connection_strings[0] : ""
      # uri = lookup(mongodbatlas_cluster.main.connection_strings.private_endpoint, aws_vpc_endpoint.ptfe_service.id)["srv_connection_string"]
    })
  }
}

locals {
  vpc_id = data.aws_vpc.default.id
  subnet_ids = tolist(data.aws_subnets.default.ids)
  ifconfig = jsondecode(data.http.my_public_ip.response_body)
  private_endpoints = flatten([for cs in mongodbatlas_cluster.main.connection_strings : cs.private_endpoint])
  connection_strings = [
    for pe in local.private_endpoints : pe.srv_connection_string
    if contains([for e in pe.endpoints : e.endpoint_id], aws_vpc_endpoint.ptfe_service.id)
  ]
}

# ----------------------- Security Groups ------------------------------

resource "aws_security_group" "main" {
  name_prefix = "atlas-sg-"
  vpc_id      = local.vpc_id
  tags = merge(
    {
      "Name" = var.cluster_name
    },
    var.tags
  )
}

resource "aws_security_group_rule" "ssh" {
 type                     = "ingress"
 from_port                = 22
 to_port                  = 22
 protocol                 = "tcp"
 description              = "SSH"
 cidr_blocks              = ["0.0.0.0/0"]
 security_group_id        = aws_security_group.main.id
}

# ports on the Atlas PL endpoint start at 1024
resource "aws_security_group_rule" "atlas-pl" {
 type                     = "ingress"
 from_port                = 1024
 to_port                  = 2024
 protocol                 = "tcp"
 description              = "SSH"
 self                     = true
 security_group_id        = aws_security_group.main.id
}

resource "aws_security_group_rule" "everything" {
 type                     = "ingress"
 from_port                = 0
 to_port                  = 65535
 protocol                 = "-1"
 description              = "Everything"
 cidr_blocks              = ["${local.ifconfig["ip"]}/32"]
 security_group_id        = aws_security_group.main.id
}

resource "aws_security_group_rule" "egress" {
 type              = "egress"
 from_port         = 0
 to_port           = 0
 protocol          = "-1"
 cidr_blocks       = ["0.0.0.0/0"]
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
  tags = merge(
    {
      "Name" = var.cluster_name
    },
    var.tags
  )
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

resource "aws_instance" "client" {
  ami           = data.aws_ami.base.id
  instance_type = var.client_instance_type
  key_name      = var.client_ssh_key_name
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id = element(
    local.subnet_ids,
    0
  )

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }

  tags = merge(
    {
      "Name" = "client-${var.cluster_name}"
    },
    var.tags
  )

  user_data = data.cloudinit_config.config.rendered
  //user_data = data.template_cloudinit_config.mongodb[each.key].rendered
}

resource "mongodbatlas_cluster" "main" {
  depends_on = [mongodbatlas_privatelink_endpoint_service.main]
  project_id   = var.project_id
  name         = var.cluster_name
  cluster_type = var.cluster_type

  replication_factor           = 3
  auto_scaling_disk_gb_enabled = true
  mongo_db_major_version = "7.0"

  //Provider Settings "block"
  provider_name               = "AWS"
  disk_size_gb                = 500
  #provider_disk_iops          = 100
  provider_volume_type        = "STANDARD"
  encryption_at_rest_provider = "NONE" // change to AWS to use CMK
  provider_instance_size_name = var.cluster_tier
  provider_region_name        = "EU_WEST_1"

  //advanced settings
  advanced_configuration {
    javascript_enabled           = false
    minimum_enabled_tls_protocol = "TLS1_2"
  }
}