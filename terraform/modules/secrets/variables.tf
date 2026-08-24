variable "name_prefix" {
  description = "Prefix used for Secrets Manager secret names"
  type        = string
}

variable "common_tags" {
  description = "Tags applied to every secret"
  type        = map(string)
  default     = {}
}

variable "recovery_window_in_days" {
  description = "Number of days during which a deleted secret can be recovered"
  type        = number
  default     = 0

  validation {
    condition = (
      var.recovery_window_in_days == 0 ||
      (var.recovery_window_in_days >= 7 && var.recovery_window_in_days <= 30)
    )
    error_message = "recovery_window_in_days must be 0 or between 7 and 30."
  }
}
