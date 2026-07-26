# terraform-aws-cloudwatch

Terraform module that manages an [Amazon
CloudWatch](https://aws.amazon.com/cloudwatch/) metric alarm, with an optional
companion log group. It creates a single alarm from the supplied metric and
threshold and can notify SNS topics or other actions on state change.

## Usage

```hcl
module "cloudwatch" {
  source = "github.com/moveeeax/terraform-aws-cloudwatch"

  alarm_name          = "cpu-high"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    InstanceId = "i-0abc123"
  }

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Notes on defaults

- **Log retention is bounded.** `log_retention_days` defaults to `14`. Leaving
  retention unset on a CloudWatch log group means log events are kept — and
  billed — forever, so this module refuses `null` and requires you to pass `0`
  explicitly if that is really what you want. Only the retention periods
  CloudWatch actually accepts are allowed; an arbitrary value such as `45` is
  rejected at plan time rather than failing during apply.
- **Log group encryption.** Set `log_group_kms_key_id` to a KMS key ARN to
  encrypt the log group with a customer-managed key. When it is left `null`,
  CloudWatch Logs still encrypts data at rest, but with a service-managed key
  you do not control. The key policy must allow the
  `logs.<region>.amazonaws.com` service principal to use the key, otherwise
  log group creation fails.
- **`treat_missing_data` defaults to `missing`**, which matches CloudWatch's own
  default: the alarm holds its current state when data points are absent. That
  means an alarm on a metric that stops being published altogether will never
  fire. Set it to `breaching` when the absence of data is itself the failure you
  want to be paged about.
- **Only static-threshold comparison operators are supported.** This module
  always sets a numeric `threshold`, so the anomaly-detection operators
  (`GreaterThanUpperThreshold`, `LessThanLowerThreshold`,
  `LessThanLowerOrGreaterThanUpperThreshold`) — which require a
  `threshold_metric_id` instead — are rejected rather than silently producing an
  alarm that AWS will not accept.
- **Required strings can't be blank.** `alarm_name`, `metric_name` and
  `namespace` are rejected at plan time if they are empty or whitespace-only,
  and every entry in `alarm_actions` must look like an ARN. This turns a
  confusing AWS API error at apply time into a clear plan-time failure.
- **Setting log group options without `create_log_group = true` is flagged.**
  `log_group_name` and `log_group_kms_key_id` only take effect when
  `create_log_group` is `true`; a `check` block warns at plan/apply time if
  either is set while the log group itself is not being created, since that
  combination is silently a no-op otherwise.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| aws       | >= 5.0   |

## Inputs

| Name                  | Description                                             | Type          | Default                   | Required |
|-----------------------|---------------------------------------------------------|---------------|---------------------------|:--------:|
| `alarm_name`          | Name of the CloudWatch metric alarm.                    | `string`      | n/a                       |   yes    |
| `comparison_operator` | Operator used to compare against the threshold. Static-threshold operators only. | `string` | `"GreaterThanThreshold"`  |    no    |
| `evaluation_periods`  | Number of periods compared to the threshold.            | `number`      | `1`                       |    no    |
| `metric_name`         | Name of the metric associated with the alarm.           | `string`      | n/a                       |   yes    |
| `namespace`           | Namespace of the metric.                                | `string`      | n/a                       |   yes    |
| `period`              | Period in seconds over which the statistic is applied.  | `number`      | `300`                     |    no    |
| `statistic`           | Statistic to apply to the metric.                       | `string`      | `"Average"`               |    no    |
| `threshold`           | Value against which the statistic is compared.          | `number`      | n/a                       |   yes    |
| `dimensions`          | Map of dimensions to scope the metric to.               | `map(string)` | `{}`                      |    no    |
| `alarm_actions`       | ARNs to notify when the alarm fires.                    | `list(string)`| `[]`                      |    no    |
| `treat_missing_data`  | How the alarm treats missing data points.               | `string`      | `"missing"`               |    no    |
| `create_log_group`    | Create a companion CloudWatch log group.                | `bool`        | `false`                   |    no    |
| `log_group_name`      | Name of the log group to create.                        | `string`      | `null`                    |    no    |
| `log_retention_days`  | Days to retain log events. `0` means retain forever.    | `number`      | `14`                      |    no    |
| `log_group_kms_key_id`| KMS key ARN used to encrypt the log group at rest.      | `string`      | `null`                    |    no    |
| `tags`                | Tags applied to the alarm and log group.                | `map(string)` | `{}`                      |    no    |

## Outputs

| Name            | Description                                        |
|-----------------|----------------------------------------------------|
| `id`            | ID of the metric alarm.                            |
| `arn`           | ARN of the metric alarm.                           |
| `alarm_name`    | Name of the metric alarm.                          |
| `log_group_arn` | ARN of the companion log group, if created.        |

## Tests

The module ships a `terraform test` suite that runs against a mocked AWS
provider, so it needs no credentials and no network access:

```sh
terraform init -backend=false
terraform test
```

The suite uses `mock_provider`, which requires Terraform (or OpenTofu) >= 1.7.
That applies to running the tests only — the module itself still supports
Terraform >= 1.5.

## License

[MIT](LICENSE)
