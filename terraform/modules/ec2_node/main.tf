resource "aws_instance" "main" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  monitoring                  = false
  subnet_id                   = var.subnet_id
  private_ip                  = var.private_ip
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = false
  iam_instance_profile        = var.iam_instance_profile_name
  user_data_replace_on_change = true
  user_data                   = var.user_data


  root_block_device {
    encrypted             = true
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true

    tags = merge(var.common_tags, {
      Name     = "${var.node_name}-root"
      NodeName = var.node_name
      Role     = var.node_role
    })

  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tags = merge(var.common_tags, {
    Name           = var.node_name
    NodeName       = var.node_name
    Role           = var.node_role
    AnsibleManaged = "true"
  })

}


resource "aws_ebs_volume" "scratch" {
  count = var.scratch_volume_size == null ? 0 : 1

  availability_zone = aws_instance.main.availability_zone
  encrypted         = true
  type              = var.scratch_volume_type
  size              = var.scratch_volume_size

  tags = merge(var.common_tags, {
    Name     = "${var.node_name}-scratch"
    NodeName = var.node_name
    Role     = var.node_role
  })
}

resource "aws_volume_attachment" "scratch" {
  count = var.scratch_volume_size == null ? 0 : 1

  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.scratch[0].id
  instance_id = aws_instance.main.id
}