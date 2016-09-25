# NOTE: bucket names are globally unique, you'll need to change this to something unique
variable "remote_state_bucket" {
    type = "string"
    default = "terraform-remote-state-asdf"
}

variable "primary_region" {
    type = "string"
    default = "us-east-1"
}

provider "aws" {
    region = "${var.primary_region}"
    profile = "terraform-bootstrap"
    alias = "terraform-bootstrap"
}

resource "aws_iam_user" "terraform-bootstrap" {
    provider = "aws.terraform-bootstrap"
    name = "terraform-bootstrap"
    force_destroy = false
}

resource "aws_iam_access_key" "terraform-bootstrap" {
    user = "${aws_iam_user.terraform-bootstrap.name}"
    provider = "aws.terraform-bootstrap"
}

resource "aws_iam_user_policy" "terraform-bootstrap-administrator-access" {
    provider = "aws.terraform-bootstrap"
    name = "AdministratorAccess"
    user = "${aws_iam_user.terraform-bootstrap.name}"

    # Copied from AWS stock AdministratorAccess policy. We could use an
    # `aws_iam_policy_attachment` resource here too, but we may want to assign the
    # AdministratorAccess policy to other users/groups/roles too and that resource
    # type doesn't play well with that according to the documentation
    # (https://www.terraform.io/docs/providers/aws/r/iam_policy_attachment.html)
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_s3_bucket" "terraform-remote-state" {
    provider = "aws.terraform-bootstrap"
    bucket = "${var.remote_state_bucket}"
    versioning {
        enabled = true
    }
}

output "terraform-bootstrap" {
    value = "${map(
        "remote_state_bucket", "${aws_s3_bucket.terraform-remote-state.name}",
        "primary_region", "${var.primary_region}",
        "iam_user", "${aws_iam_user.terraform-bootstrap.name}",
        "iam_user_access_key_id", "${aws_iam_access_key.terraform-bootstrap.id}",
        "iam_secret_access_key", "${aws_iam_access_key.terraform-bootstrap.secret}"
    )}"
}

output "remote_state_config_command" {
    value = "${join(" ", list(
        "terraform remote config",
        "-backend=s3",
        "-backend-config=\"bucket=${aws_s3_bucket.terraform-remote-state.bucket}\" "
        "-backend-config=\"key=terraform-bootstrap.tfstate\" ",
        "-backend-config=\"profile=terraform-bootstrap\" ",
        "-backend-config=\"region=${var.primary_region}\" "
    ))}"
}

output "aws_credentials_entry" {
    value = "${join("\n", list(
        "# IAM: terraform-bootstrap",
        "[terraform-bootstrap]",
        "aws_access_key_id = ${aws_iam_access_key.terraform-bootstrap.id}",
        "aws_secret_access_key = ${aws_iam_access_key.terraform-bootstrap.secret}"
    ))}"
}
