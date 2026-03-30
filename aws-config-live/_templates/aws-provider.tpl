# provider configuration

provider "aws" {
  region = "${current_region}"

  allowed_account_ids = ["${account_id}"]

  default_tags {
    tags = {
      %{~ for k, v in default_tags ~}
      ${k} = "${v}"
      %{~ endfor ~}
    }
  }
}
