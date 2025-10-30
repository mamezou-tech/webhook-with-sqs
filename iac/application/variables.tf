variable "prefix" {
  type = string
}

variable "application" {
  type = object({
    runtime = optional(string, "python3.13")
    timeout = optional(number, 3)
  })
  default = {}
}

variable "api_gateway" {
  type = object({
    api_id        = string
    execution_arn = string
  })
}

