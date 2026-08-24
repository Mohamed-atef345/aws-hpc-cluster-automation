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

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  for_each = aws_iam_role.instance

  role       = each.value.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
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

data "aws_iam_policy_document" "freeipa_secrets" {
  count = length(var.freeipa_secret_arns) > 0 ? 1 : 0

  statement {
    sid = "ReadFreeIPASecrets"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]

    resources = var.freeipa_secret_arns
  }
}

resource "aws_iam_role_policy" "freeipa_secrets" {
  count = length(var.freeipa_secret_arns) > 0 ? 1 : 0

  name   = "${var.name_prefix}-freeipa-secrets"
  role   = aws_iam_role.instance["freeipa"].id
  policy = data.aws_iam_policy_document.freeipa_secrets[0].json
}

data "aws_iam_policy_document" "controller_secrets" {
  count = length(var.controller_secret_arns) > 0 ? 1 : 0

  statement {
    sid = "ReadControllerSecrets"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]

    resources = var.controller_secret_arns
  }
}

resource "aws_iam_role_policy" "controller_secrets" {
  count = length(var.controller_secret_arns) > 0 ? 1 : 0

  name   = "${var.name_prefix}-controller-secrets"
  role   = aws_iam_role.instance["controller"].id
  policy = data.aws_iam_policy_document.controller_secrets[0].json
}
