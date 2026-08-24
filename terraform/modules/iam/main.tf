locals {
  instance_roles = toset([
    "freeipa",
    "controller",
    "login",
    "compute",
  ])
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  for_each = local.instance_roles

  name               = "${var.name_prefix}-${each.key}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.name_prefix}-${each.key}-role"
    Role = each.key
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  for_each = aws_iam_role.instance

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  for_each = aws_iam_role.instance

  name = "${var.name_prefix}-${each.key}-profile"
  role = each.value.name

  tags = {
    Name = "${var.name_prefix}-${each.key}-profile"
    Role = each.key
  }
}

data "aws_iam_policy_document" "secrets" {
  for_each = {
    for role, secret_arns in var.secret_arns_by_role :
    role => secret_arns if length(secret_arns) > 0
  }

  statement {
    sid = "ReadNodeSecrets"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]

    resources = each.value
  }
}

resource "aws_iam_role_policy" "secrets" {
  for_each = data.aws_iam_policy_document.secrets

  name   = "${var.name_prefix}-${each.key}-secrets"
  role   = aws_iam_role.instance[each.key].id
  policy = each.value.json
}
