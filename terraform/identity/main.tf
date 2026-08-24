module "iam" {
  source = "../modules/iam"

  name_prefix            = var.name_prefix
  freeipa_secret_arns    = local.freeipa_secret_arns
  controller_secret_arns = local.controller_secret_arns
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    sid     = "GitHubActionsAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_oidc_subject]
    }
  }
}

resource "aws_iam_role" "github_terraform" {
  name                 = "${var.name_prefix}-github-terraform-role"
  description          = "Short-lived GitHub Actions role for the HPC Terraform deployment"
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role.json
  max_session_duration = 3600

  tags = {
    Name = "${var.name_prefix}-github-terraform-role"
    Role = "terraform-deployment"
  }
}

data "aws_iam_policy_document" "terraform_state" {
  statement {
    sid       = "ListStateBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket_name}"]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = [
        dirname(var.state_key),
        "${dirname(var.state_key)}/*",
      ]
    }
  }

  statement {
    sid = "ReadWriteState"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket_name}/${var.state_key}",
    ]
  }

  statement {
    sid = "ManageStateLock"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.state_bucket_name}/${var.state_key}.tflock",
    ]
  }
}

resource "aws_iam_role_policy" "terraform_state" {
  name   = "${var.name_prefix}-terraform-state"
  role   = aws_iam_role.github_terraform.id
  policy = data.aws_iam_policy_document.terraform_state.json
}

data "aws_iam_policy_document" "terraform_infrastructure" {
  statement {
    sid = "ReadProjectInfrastructure"
    actions = [
      "cloudwatch:DescribeAlarms",
      "cloudwatch:GetDashboard",
      "cloudwatch:ListDashboards",
      "ec2:Describe*",
      "elasticfilesystem:Describe*",
      "logs:Describe*",
      "logs:ListTagsForResource",
      "secretsmanager:DescribeSecret",
      "secretsmanager:ListSecrets",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ManageProjectNetworkAndCompute"
    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:AttachVolume",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:CreatePlacementGroup",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:CreateVpc",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteNatGateway",
      "ec2:DeletePlacementGroup",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DeleteVpc",
      "ec2:DetachInternetGateway",
      "ec2:DetachVolume",
      "ec2:DisassociateRouteTable",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:ReleaseAddress",
      "ec2:ReplaceRoute",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RunInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ManageProjectEFS"
    actions = [
      "elasticfilesystem:CreateFileSystem",
      "elasticfilesystem:CreateMountTarget",
      "elasticfilesystem:DeleteFileSystem",
      "elasticfilesystem:DeleteMountTarget",
      "elasticfilesystem:TagResource",
      "elasticfilesystem:UntagResource",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ManageProjectSecrets"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:RestoreSecret",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:UpdateSecret",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/*",
    ]
  }

  statement {
    sid = "ManageProjectObservability"
    actions = [
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DeleteDashboards",
      "cloudwatch:PutDashboard",
      "cloudwatch:PutMetricAlarm",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DeleteRetentionPolicy",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
    ]
    resources = ["*"]
  }

}

resource "aws_iam_role_policy" "terraform_infrastructure" {
  name   = "${var.name_prefix}-terraform-infrastructure"
  role   = aws_iam_role.github_terraform.id
  policy = data.aws_iam_policy_document.terraform_infrastructure.json
}

data "aws_iam_policy_document" "pass_instance_roles" {
  statement {
    sid       = "PassProjectEC2Roles"
    actions   = ["iam:PassRole"]
    resources = values(module.iam.instance_role_arns)

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "pass_instance_roles" {
  name   = "${var.name_prefix}-pass-instance-roles"
  role   = aws_iam_role.github_terraform.id
  policy = data.aws_iam_policy_document.pass_instance_roles.json
}
