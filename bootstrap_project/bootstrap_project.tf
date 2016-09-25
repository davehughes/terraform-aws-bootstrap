variable "remote_state_bucket" {
    type = "string"
    default = "terraform-remote-state-asdf"
}

variable "primary_region" {
    type = "string"
    default = "us-east-1"
}

variable "project" {
    type = "string"
    default = "myproject"  # TODO: remove this default
}

provider "aws" {
    # IAM: terraform-bootstrap (global bootstrap user)
    region = "us-east-1"
    alias = "terraform-bootstrap-project"
    profile = "terraform-bootstrap"
}

# project-specific terraform user
resource "aws_iam_user" "terraform-admin" {
    name = "terraform-${var.project}"
    provider = "aws.terraform-bootstrap-project"
}

resource "aws_iam_access_key" "terraform-admin" {
    user = "${aws_iam_user.terraform-admin.name}"
    provider = "aws.terraform-bootstrap-project"
}

resource "aws_iam_user_policy" "terraform-admin-access" {
    provider = "aws.terraform-bootstrap-project"
    name = "admin-access"
    user = "${aws_iam_user.terraform-admin.name}"
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

output "admin_config" {
    # "remote_state_bucket", "${aws_s3_bucket.terraform-remote-state.name}",
    # "primary_region", "${var.primary_region}",
    value = "${map(
        "iam_user", "${aws_iam_user.terraform-admin.name}",
        "iam_user_access_key_id", "${aws_iam_access_key.terraform-admin.id}",
        "iam_secret_access_key", "${aws_iam_access_key.terraform-admin.secret}"
    )}"
}

output "remote_state_config_command" {
    value = "${join(" ", list(
        "terraform remote config",
        "-backend=s3",
        "-backend-config=\"bucket=${var.remote_state_bucket}\" ",
        "-backend-config=\"key=${var.project}.tfstate\" ",
        "-backend-config=\"profile=terraform-${var.project}\" ",
        "-backend-config=\"region=${var.primary_region}\" "
    ))}"
}

output "aws_credentials_entry" {
    value = "${join("\n", list(
        "# IAM: terraform-${var.project}",
        "[terraform-${var.project}]",
        "aws_access_key_id = ${aws_iam_access_key.terraform-admin.id}",
        "aws_secret_access_key = ${aws_iam_access_key.terraform-admin.secret}"
    ))}"
}
