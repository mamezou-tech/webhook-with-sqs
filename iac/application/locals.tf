locals {
  prefix = var.prefix

  lambda_script_dir = "lambda"
  module_name       = "webhook_application"
  function_name     = "${local.prefix}-${replace(local.module_name, "_", "-")}"
  source_path       = "${local.lambda_script_dir}/${local.module_name}.py"
}
