resource "aws_cloudwatch_metric_alarm" "this" {
  alarm_name          = var.alarm_name
  comparison_operator = var.comparison_operator
  evaluation_periods  = var.evaluation_periods
  metric_name         = var.metric_name
  namespace           = var.namespace
  period              = var.period
  statistic           = var.statistic
  threshold           = var.threshold
  dimensions          = var.dimensions
  alarm_actions       = var.alarm_actions
  treat_missing_data  = var.treat_missing_data

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "this" {
  count = var.create_log_group ? 1 : 0

  name              = var.log_group_name
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_group_kms_key_id

  tags = var.tags

  lifecycle {
    precondition {
      condition     = try(trimspace(var.log_group_name), "") != ""
      error_message = "log_group_name must be set to a non-empty value when create_log_group is true."
    }
  }
}

check "log_group_settings_require_create_log_group" {
  assert {
    condition     = var.create_log_group || (var.log_group_name == null && var.log_group_kms_key_id == null)
    error_message = "log_group_name and/or log_group_kms_key_id are set but create_log_group is false, so they have no effect. Set create_log_group = true or remove these values."
  }
}
