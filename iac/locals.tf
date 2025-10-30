locals {
  prefix = "mz-dev"
  # snake_prefix = "mz_dev"

  # for queue
  webhook_queue_name = "${local.prefix}-webhook-queue"
  message_group_id   = "${local.prefix}-sqs-webhook"
  processing_timeout = 60

  # for lambda of webhook event producer
  lambda_script_dir                          = "lambda"
  webhook_event_producer_module_name         = "webhook_event_producer"
  webhook_event_producer_kebabu_name         = replace(local.webhook_event_producer_module_name, "_", "-")
  webhook_event_producer_execution_role_name = "${local.prefix}-${local.webhook_event_producer_kebabu_name}-execution-role"
  webhook_event_producer_function_name       = "${local.prefix}-${local.webhook_event_producer_kebabu_name}"
  webhook_event_producer_source_template     = "${local.lambda_script_dir}/${local.webhook_event_producer_module_name}.py"
}
