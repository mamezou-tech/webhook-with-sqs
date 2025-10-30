# API Gateway
variable "apigw_name" {
  type = string
}

variable "log_retention_in_days" {
  type    = number
  default = 7
}

variable "webhook" {
  type = object({
    runtime              = optional(string, "python3.13")
    max_receive_count    = optional(number, 1)
    log_level            = optional(string, "INFO")
    max_concurrency      = optional(number, 2)
    dlq_retention_second = optional(number, 345600) # 4 days
  })
}
