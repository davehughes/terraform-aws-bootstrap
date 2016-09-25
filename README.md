TODO:
* Write up a basic summary of the design here (global tfstate with many per-project tfstates using remote state)
* Create an unprivileged user that is only permitted to read the global bootstrap configuration for the purposes of importing state (?)

Bootstrapping the bootstrap:
* To use Terraform at all, we need a set of credentials for performing administrative tasks. Create an IAM user named 'terraform-bootstrap' and attach a policy named AdministratorAccess (Permissions tab -> Attach Policy) with the following contents:
```
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
```
* Install [aws-cli](https://docs.aws.amazon.com/cli/latest/userguide/installing.html) and create a profile with the credentials of the terraform-bootstrap user:
```
# in ~/.aws/credentials
[terraform-bootstrap]
aws_access_key_id = <access key>
aws_secret_access_key = <secret key>
```

* Import the admin user for management via terraform:
```
AWS_DEFAULT_REGION=<default_region> AWS_PROFILE=terraform-bootstrap terraform import "aws_iam_user.terraform-bootstrap" "terraform-bootstrap"
```

* Run `terraform plan` to validate that the correct actions are planned, then run `terraform apply`.  You will be be prompted for the two variables:
** `remote_state_bucket` - A unique name for the bucket to store terraform state in. S3 buckets are in one global namespace, so you'll see the following error if you have chosen a bucket name that already exists:
```
* aws_s3_bucket.terraform-remote-state: Error creating S3 bucket: BucketAlreadyExists: The requested bucket name is not available. The bucket namespace is shared by all users of the system. Please select a different name and try again. status code: 409, request id: F144F0642E53A6B7
```
** `primary_region` - The primary AWS region to create the remote state bucket in.

* Enable remote state storage for the project.  The command to do this is conveniently included in the terraform output in a variable called 'remote_state_config_command'. If you have [jq](https://stedolan.github.io/jq/) installed, you can do the following:
```
bash -c $(terraform output -json | jq --raw-output ".remote_state_config_command.value")
```
* (Optional) Delete and replace the credentials used created manually in the first step.  The bootstrap process creates a new set of access credentials, so we no longer
need the original ones.  Run the following to get the new credentials and replace the existing `[terraform-bootstrap]` section in `~/.aws/credentials`:
```
terraform output -json | jq --raw-output ".aws_credentials_entry.value"
```

Bootstrapping a project (requires 'terraform-bootstrap' AWS profile configured above):
* Create a directory for the new project and copy the `bootstrap_project/bootstrap_project.tf` there.
* Run `terraform plan` to validate that the correct actions are planned, then run `terraform apply`.
* Fill in awscli profile with credentials from output:
```
> terraform output -json | jq --raw-output ".aws_credentials_entry.value"
[terraform-<project>]
aws_access_key_id = <access key>
aws_secret_access_key = <secret key>
```
* Configure terraform remote state syncing to global terraform remote state bucket (configured above):
```
> CMD = $(terraform output -json | jq --raw-output ".remote_state_config_command.value")
> echo $CMD
terraform remote config -backend=s3 -backend-config="bucket=<remote state bucket>"  -backend-config="key=<project>.tfstate"  -backend-config="profile=terraform-<project>"  -backend-config="region=us-east-1" 
bash -c $CMD
```
