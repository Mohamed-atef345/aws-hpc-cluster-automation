resource "aws_efs_file_system" "main" {
  creation_token         = var.project_name
  encrypted              = var.encrypted
  availability_zone_name = var.availability_zone
  performance_mode       = var.performance_mode
  throughput_mode        = var.throughput_mode

  tags = {
    Name = "${var.project_name}-efs"
    Role = "shared-storage"
  }
}


resource "aws_efs_mount_target" "mount_target" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.private_subnet_id
  security_groups = [var.efs_security_group_id]
}

resource "aws_efs_access_point" "home" {
  file_system_id = aws_efs_file_system.main.id
  root_directory {
    path = "/home"
    creation_info {
      owner_uid   = 0
      owner_gid   = 0
      permissions = 0755
    }
  }
}

resource "aws_efs_access_point" "shared" {
  file_system_id = aws_efs_file_system.main.id
  root_directory {
    path = "/shared"
    creation_info {
      owner_uid   = 0
      owner_gid   = 0
      permissions = 0775
    }
  }
}