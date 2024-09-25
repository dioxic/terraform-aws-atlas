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

//data "template_file" "bootstrap" {
//  template = file("${path.module}/scripts/bootstrap.sh")
//}

data "cloudinit_config" "config" {
  base64_encode = true
  gzip          = true
  part {
    content_type = "text/x-shellscript"
    content = file("${path.module}/scripts/bootstrap.sh")
  }
}

locals {
  vpc_id = data.aws_vpc.default.id
  subnet_ids = tolist(data.aws_subnets.default.ids)
  ifconfig = jsondecode(data.http.my_public_ip.response_body)
}

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

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

# resource "mongodbatlas_database_user" "root" {
#   username           = "root"
#   password           = random_password.password.result
#   project_id         = var.project_id
#   auth_database_name = "admin"
#
#   roles {
#     role_name     = "dba"
#     database_name = "admin"
#   }
# }

# resource "mongodbatlas_database_user" "service" {
#   username           = "myService"
#   password           = random_password.password.result
#   project_id         = var.project_id
#   auth_database_name = "admin"
#
#   roles {
#     role_name     = "service"
#     database_name = "admin"
#   }
# }

//resource "mongodbatlas_auditing" "test" {
//  project_id                  = var.project_id
//  audit_filter                = file("${path.module}/config/audit-filter.json")
//  audit_authorization_success = true
//  enabled                     = true
//}
//
//resource "mongodbatlas_encryption_at_rest" "main" {
//  project_id = var.project_id
//
//  aws_kms = {
//    enabled                = true
//    access_key_id          = "AKIAIOSFODNN7EXAMPLE"
//    secret_access_key      = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
//    customer_master_key_id = "030gce02-586d-48d2-a966-05ea954fde0g"
//    region                 = "US_EAST_1"
//  }
//}
//
//resource "mongodbatlas_maintenance_window" "main" {
//  project_id  = var.project_id
//  day_of_week = 3
//  hour_of_day = 4
//}
//
//resource "mongodbatlas_cloud_provider_snapshot_backup_policy" "main" {
//  project_id   = var.project_id
//  cluster_name = mongodbatlas_cluster.main.name
//
//  reference_hour_of_day    = 3
//  reference_minute_of_hour = 45
//  restore_window_days      = 4
//
//  //Keep all 4 default policies but modify the units and values
//  //Could also just reflect the policy defaults here for later management
//  policies {
//    id = mongodbatlas_cluster.main.snapshot_backup_policy.0.policies.0.id
//
//    policy_item {
//      id                 = mongodbatlas_cluster.main.snapshot_backup_policy.0.policies.0.policy_item.0.id
//      frequency_interval = 1
//      frequency_type     = "hourly"
//      retention_unit     = "days"
//      retention_value    = 1
//    }
//
//    policy_item {
//      id                 = mongodbatlas_cluster.main.snapshot_backup_policy.0.policies.0.policy_item.1.id
//      frequency_interval = 1
//      frequency_type     = "daily"
//      retention_unit     = "days"
//      retention_value    = 2
//    }
//
//    policy_item {
//      id                 = mongodbatlas_cluster.main.snapshot_backup_policy.0.policies.0.policy_item.2.id
//      frequency_interval = 4
//      frequency_type     = "weekly"
//      retention_unit     = "weeks"
//      retention_value    = 3
//    }
//
//    policy_item {
//      id                 = mongodbatlas_cluster.main.snapshot_backup_policy.0.policies.0.policy_item.3.id
//      frequency_interval = 5
//      frequency_type     = "monthly"
//      retention_unit     = "months"
//      retention_value    = 4
//    }
//  }
//}
//
//resource "mongodbatlas_alert_configuration" "assert_regular" {
//  project_id = var.project_id
//  event_type = "OUTSIDE_METRIC_THRESHOLD"
//  enabled    = true
//
//  notification {
//    type_name     = "GROUP"
//    interval_min  = 5
//    delay_min     = 0
//    sms_enabled   = false
//    email_enabled = true
//    roles         = ["GROUP_CHARTS_ADMIN", "GROUP_CLUSTER_MANAGER"]
//  }
//
//  matcher {
//    field_name = "HOSTNAME_AND_PORT"
//    operator   = "EQUALS"
//    value      = "SECONDARY"
//  }
//
//  metric_threshold = {
//    metric_name = "ASSERT_REGULAR"
//    operator    = "LESS_THAN"
//    threshold   = 99.0
//    units       = "RAW"
//    mode        = "AVERAGE"
//  }
//}


resource "aws_instance" "bastion" {
  ami           = data.aws_ami.base.id
  instance_type = var.bastion_instance_type
  key_name      = var.bastion_ssh_key_name
  vpc_security_group_ids = [aws_security_group.main.id]
  subnet_id = element(
    local.subnet_ids,
    0
  )

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  tags = merge(
    {
      "Name" = "bastion-${var.cluster_name}"
    },
    var.tags
  )

  user_data = data.cloudinit_config.config.rendered
  //user_data = data.template_cloudinit_config.mongodb[each.key].rendered
}

resource "mongodbatlas_cluster" "main" {
  project_id   = var.project_id
  name         = var.cluster_name
  cluster_type = var.cluster_type

  replication_factor           = 3
  auto_scaling_disk_gb_enabled = true
  mongo_db_major_version = "7.0"

  //Provider Settings "block"
  provider_name               = "AWS"
  disk_size_gb                = 50
  #provider_disk_iops          = 100
  provider_volume_type        = "STANDARD"
  encryption_at_rest_provider = "NONE" // change to AWS to use CMK
  provider_instance_size_name = "M10"
  provider_region_name        = "EU_WEST_1"

  //advanced settings
  advanced_configuration {
    javascript_enabled           = false
    minimum_enabled_tls_protocol = "TLS1_2"
  }
}