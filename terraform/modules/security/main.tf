resource "aws_security_group" "this" {
  for_each = local.security_groups

  name_prefix            = "${var.project_name}-${each.key}-"
  description            = each.value.description
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = {
    Name = "${var.project_name}-${each.key}-sg"
    Role = each.key
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "internal" {
  for_each = local.ingress_rules

  security_group_id            = aws_security_group.this[each.value.target_sg].id
  referenced_security_group_id = aws_security_group.this[each.value.source_sg].id

  description = each.value.description
  ip_protocol = each.value.protocol
  from_port   = each.value.from_port
  to_port     = each.value.to_port
}

resource "aws_vpc_security_group_egress_rule" "all_ipv4" {
  for_each = aws_security_group.this

  security_group_id = each.value.id
  description       = "Allow all outbound IPv4 traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

