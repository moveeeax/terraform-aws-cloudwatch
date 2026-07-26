# Run with `terraform test` (or `tofu test`) from the repository root.
#
# NOTE: `mock_provider` requires Terraform >= 1.7 / OpenTofu >= 1.7. That is a
# requirement of this test suite only — the module itself still supports the
# `required_version = ">= 1.5"` declared in versions.tf, so do not bump it.

mock_provider "aws" {}

variables {
  alarm_name  = "test-cpu-high"
  metric_name = "CPUUtilization"
  namespace   = "AWS/EC2"
  threshold   = 80
}

run "defaults_are_safe" {
  assert {
    condition     = aws_cloudwatch_metric_alarm.this.comparison_operator == "GreaterThanThreshold"
    error_message = "Default comparison_operator changed unexpectedly."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this.treat_missing_data == "missing"
    error_message = "Default treat_missing_data changed unexpectedly."
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 0
    error_message = "No log group should be created unless create_log_group is true."
  }
}

run "log_group_has_bounded_retention_by_default" {
  variables {
    create_log_group = true
    log_group_name   = "/test/example"
  }

  # An unset retention means CloudWatch Logs keeps — and bills for — log events
  # forever. The module must default to a finite retention.
  assert {
    condition     = aws_cloudwatch_log_group.this[0].retention_in_days == 14
    error_message = "Log group retention must default to a finite number of days, not never-expire."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this[0].retention_in_days != 0
    error_message = "Default log retention must not be 0 (retain forever)."
  }
}

run "log_group_accepts_a_kms_key" {
  variables {
    create_log_group     = true
    log_group_name       = "/test/encrypted"
    log_group_kms_key_id = "arn:aws:kms:us-east-1:111122223333:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this[0].kms_key_id == "arn:aws:kms:us-east-1:111122223333:key/00000000-0000-0000-0000-000000000000"
    error_message = "log_group_kms_key_id must be passed through to the log group so it is encrypted with a customer-managed key."
  }
}

run "log_group_requires_a_name" {
  # The precondition fires during planning, so this run must stop at plan.
  command = plan

  variables {
    create_log_group = true
    log_group_name   = null
  }

  expect_failures = [aws_cloudwatch_log_group.this]
}

run "rejects_anomaly_detection_comparison_operator" {
  command = plan

  variables {
    comparison_operator = "GreaterThanUpperThreshold"
  }

  expect_failures = [var.comparison_operator]
}

run "rejects_invalid_comparison_operator" {
  command = plan

  variables {
    comparison_operator = "GreaterThan"
  }

  expect_failures = [var.comparison_operator]
}

run "rejects_miscased_treat_missing_data" {
  command = plan

  variables {
    treat_missing_data = "notbreaching"
  }

  expect_failures = [var.treat_missing_data]
}

run "rejects_invalid_statistic" {
  command = plan

  variables {
    statistic = "Median"
  }

  expect_failures = [var.statistic]
}

run "rejects_invalid_period" {
  command = plan

  variables {
    period = 45
  }

  expect_failures = [var.period]
}

run "rejects_zero_evaluation_periods" {
  command = plan

  variables {
    evaluation_periods = 0
  }

  expect_failures = [var.evaluation_periods]
}

run "rejects_unsupported_retention_period" {
  command = plan

  variables {
    log_retention_days = 45
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_null_retention_period" {
  command = plan

  variables {
    log_retention_days = null
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_kms_key_alias_instead_of_arn" {
  command = plan

  variables {
    log_group_kms_key_id = "alias/aws/logs"
  }

  expect_failures = [var.log_group_kms_key_id]
}

run "rejects_empty_alarm_name" {
  command = plan

  variables {
    alarm_name = "   "
  }

  expect_failures = [var.alarm_name]
}

run "rejects_empty_metric_name" {
  command = plan

  variables {
    metric_name = ""
  }

  expect_failures = [var.metric_name]
}

run "rejects_empty_namespace" {
  command = plan

  variables {
    namespace = ""
  }

  expect_failures = [var.namespace]
}

run "rejects_malformed_alarm_action_arn" {
  command = plan

  variables {
    alarm_actions = ["not-an-arn"]
  }

  expect_failures = [var.alarm_actions]
}

run "accepts_high_resolution_period" {
  # 10-second periods are a valid high-resolution value distinct from the
  # multiple-of-60 branch of the period validation; make sure that branch
  # is actually exercised by a passing case, not just the rejection tests.
  variables {
    period = 10
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.this.period == 10
    error_message = "High-resolution period of 10 seconds should be accepted and passed through."
  }
}

run "log_group_with_multiple_optional_settings_together" {
  # Exercises create_log_group, a non-default retention, and a KMS key all
  # set at once, rather than each in isolation as the earlier runs do.
  variables {
    create_log_group     = true
    log_group_name       = "/test/combined"
    log_retention_days   = 0
    log_group_kms_key_id = "arn:aws:kms:us-east-1:111122223333:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = aws_cloudwatch_log_group.this[0].retention_in_days == 0
    error_message = "Explicit retain-forever retention (0) must be honored when combined with other log group settings."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this[0].kms_key_id == "arn:aws:kms:us-east-1:111122223333:key/00000000-0000-0000-0000-000000000000"
    error_message = "KMS key must be honored when combined with other log group settings."
  }
}

run "warns_when_log_group_settings_set_without_create_log_group" {
  # create_log_group stays false while log_group_name is set: the setting
  # would silently be ignored, which the check block should flag.
  command = plan

  variables {
    log_group_name = "/test/ignored"
  }

  expect_failures = [check.log_group_settings_require_create_log_group]
}
