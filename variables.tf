variable "alarm_name" {
  description = "Name of the CloudWatch metric alarm."
  type        = string

  validation {
    condition     = trimspace(var.alarm_name) != ""
    error_message = "alarm_name must not be empty."
  }
}

variable "comparison_operator" {
  description = "Operator used to compare the statistic against the threshold. Only the static-threshold operators are supported, because this module always sets a numeric `threshold`; the anomaly-detection operators require a `threshold_metric_id` instead."
  type        = string
  default     = "GreaterThanThreshold"

  validation {
    condition = contains([
      "GreaterThanOrEqualToThreshold",
      "GreaterThanThreshold",
      "LessThanThreshold",
      "LessThanOrEqualToThreshold",
    ], var.comparison_operator)
    error_message = "comparison_operator must be one of GreaterThanOrEqualToThreshold, GreaterThanThreshold, LessThanThreshold or LessThanOrEqualToThreshold. Anomaly-detection operators (LessThanLowerOrGreaterThanUpperThreshold, LessThanLowerThreshold, GreaterThanUpperThreshold) are not supported because they need a threshold_metric_id rather than a static threshold."
  }
}

variable "evaluation_periods" {
  description = "Number of periods over which data is compared to the threshold."
  type        = number
  default     = 1

  validation {
    condition     = var.evaluation_periods >= 1 && floor(var.evaluation_periods) == var.evaluation_periods
    error_message = "evaluation_periods must be a whole number of at least 1."
  }
}

variable "metric_name" {
  description = "Name of the metric associated with the alarm."
  type        = string

  validation {
    condition     = trimspace(var.metric_name) != ""
    error_message = "metric_name must not be empty."
  }
}

variable "namespace" {
  description = "Namespace of the metric associated with the alarm."
  type        = string

  validation {
    condition     = trimspace(var.namespace) != ""
    error_message = "namespace must not be empty."
  }
}

variable "period" {
  description = "Period in seconds over which the statistic is applied. CloudWatch accepts 10, 20 or 30 (high resolution metrics only) or any multiple of 60."
  type        = number
  default     = 300

  validation {
    condition     = contains([10, 20, 30], var.period) || (var.period >= 60 && var.period % 60 == 0)
    error_message = "period must be 10, 20, 30 or a multiple of 60."
  }
}

variable "statistic" {
  description = "Statistic to apply to the metric, for example Average or Sum."
  type        = string
  default     = "Average"

  validation {
    condition     = contains(["SampleCount", "Average", "Sum", "Minimum", "Maximum"], var.statistic)
    error_message = "statistic must be one of SampleCount, Average, Sum, Minimum or Maximum."
  }
}

variable "threshold" {
  description = "Value against which the statistic is compared."
  type        = number
}

variable "dimensions" {
  description = "Map of dimensions to scope the metric to."
  type        = map(string)
  default     = {}
}

variable "alarm_actions" {
  description = "List of ARNs to notify when the alarm transitions into ALARM state."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.alarm_actions : can(regex("^arn:[a-z0-9-]+:", arn))])
    error_message = "Every entry in alarm_actions must be a valid ARN (arn:<partition>:...)."
  }
}

variable "treat_missing_data" {
  description = "How the alarm treats missing data points. `missing` (the CloudWatch default) keeps the alarm in its current state, so an alarm on a metric that stops reporting altogether will never fire; use `breaching` if the absence of data should itself be treated as a problem."
  type        = string
  default     = "missing"

  validation {
    condition     = contains(["missing", "ignore", "breaching", "notBreaching"], var.treat_missing_data)
    error_message = "treat_missing_data must be one of missing, ignore, breaching or notBreaching (values are case sensitive)."
  }
}

variable "create_log_group" {
  description = "Whether to create a companion CloudWatch log group."
  type        = bool
  default     = false
}

variable "log_group_name" {
  description = "Name of the log group to create when create_log_group is true. Required when create_log_group is true."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Number of days to retain log events in the log group. Use `0` to retain log events forever — note that CloudWatch Logs bills for stored data indefinitely in that case. Must be one of the retention periods CloudWatch accepts."
  type        = number
  default     = 14

  validation {
    condition = var.log_retention_days != null && contains([
      0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731,
      1096, 1827, 2192, 2557, 2922, 3288, 3653,
    ], var.log_retention_days)
    error_message = "log_retention_days must be one of 0 (retain forever), 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288 or 3653. Pass 0 explicitly rather than null if you really want to retain — and pay for — log events forever."
  }
}

variable "log_group_kms_key_id" {
  description = "ARN of the KMS key used to encrypt the log group at rest. When null, CloudWatch Logs uses its own service-managed key. The key policy must allow the `logs.<region>.amazonaws.com` service principal to use it."
  type        = string
  default     = null

  validation {
    condition     = var.log_group_kms_key_id == null || can(regex("^arn:[a-z0-9-]+:kms:", var.log_group_kms_key_id))
    error_message = "log_group_kms_key_id must be a KMS key ARN (arn:<partition>:kms:...), not a key ID or alias."
  }
}

variable "tags" {
  description = "Tags applied to the alarm and log group."
  type        = map(string)
  default     = {}
}
