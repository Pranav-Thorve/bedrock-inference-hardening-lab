# Bedrock inference hardening lab

An internal LLM inference API on AWS, deployed broken on purpose, then fixed one failure at a time. Terraform holds every stage, so each fix is an apply and a diff rather than a console click.

Not production. Use a throwaway account. Tear it down when you are done.

## Path

`client -> API Gateway -> Lambda -> Amazon Bedrock`, with CloudTrail, Bedrock invocation logging and API Gateway access logs recording what happens.

## The three failures

| Failure | Broken state | Fixed at |
| --- | --- | --- |
| 1. Over-broad Lambda role | `bedrock:*` and `logs:*` on `*` | stage 4 |
| 2. Throttle gap | no usage plan, no API key, no WAF | stage 1 |
| 3. Exception leak | 500s return `str(e)` plus `os.environ`, and log the same to CloudWatch | stage 2 |

## Stages

`lab_stage` maps to the attack escalation table in the lab plan.

| Stage | What is fixed | Handler | Apply |
| --- | --- | --- | --- |
| 0 | nothing | `handler_stage0.py` | `terraform apply -var lab_stage=0` |
| 1 | usage plan, API key, stage throttle, WAF rate rule | `handler_stage0.py` | `-var lab_stage=1` |
| 2 | exception handling, no env in the response or the log | `handler_stage2.py` | `-var lab_stage=2` |
| 3 | output filter on every response path | `handler_stage3.py` | `-var lab_stage=3` |
| 4 | Lambda role scoped to one model and one log group | `handler_stage3.py` | `-var lab_stage=4` |

The code diff for the writeup:

```bash
diff -u src/handler_stage0.py src/handler_stage2.py   # Failure 3 fixed
diff -u src/handler_stage2.py src/handler_stage3.py   # output filter hardened
terraform plan -var lab_stage=4                       # Failure 1 fixed, IAM diff
```

## Prerequisites

1. AWS CLI identity in a throwaway account. These files take no account ID, they use the identity already on your machine.
2. **Bedrock model access.** Anthropic models refuse to run until the account has submitted use case details. Without it every call fails with `ResourceNotFoundException: Model use case details have not been submitted for this account`, which at stage 0 is still a 500 with a credential dump but never a working inference. Console: Amazon Bedrock, Model access, Anthropic use case details. Check with:

```bash
aws bedrock get-use-case-for-model-access
```

3. Confirm the model in `variables.tf` is actually offered in your region:

```bash
aws bedrock list-foundation-models --by-provider anthropic \
  --query 'modelSummaries[].{id:modelId,status:modelLifecycle.status}' --output table
```

4. If the account sits under an SCP that restricts `bedrock:PutModelInvocationLoggingConfiguration`, set `bedrock_logging_role_arn` to a role the SCP exempts. Leave it empty otherwise.

## Deploy

```bash
export AWS_PROFILE=lab
export AWS_REGION=us-east-1
aws sts get-caller-identity
terraform init
terraform apply -var lab_stage=0
```

Optional `terraform.tfvars`, kept out of git:

```hcl
budget_alert_email       = "you@example.com"
bedrock_logging_role_arn = "arn:aws:iam::<account>:role/<scp-exempt-role>"
```

## Invoke

```bash
INVOKE_URL=$(terraform output -raw invoke_url)

# inference
curl -sS -X POST "$INVOKE_URL" -H 'Content-Type: application/json' \
  -d '{"prompt":"Say hello in one sentence."}'

# Failure 3: leaked environment and live Lambda credentials
curl -sS -X POST "$INVOKE_URL" -H 'Content-Type: application/json' \
  -d '{"prompt":"__crash__"}'

# stage 1 and later, the key is required
curl -sS -X POST "$INVOKE_URL" -H 'Content-Type: application/json' \
  -H "x-api-key: $(terraform output -raw api_key)" -d '{"prompt":"hello"}'
```

## Evidence

| What you want to show | Where it is |
| --- | --- |
| Request rate, source IP, status, throttle and WAF outcome | `terraform output apigw_access_log_group` |
| The leaked credential string | `terraform output lambda_log_group` |
| Prompt injection payload and the model's reply | `terraform output bedrock_invocation_log_group` |
| Bedrock InvokeModel API calls | CloudTrail data events in `terraform output cloudtrail_bucket` |
| WAF rate-rule blocks | `terraform output waf_log_group`, stage 1 and later |
| Blast radius before and after | `terraform output bedrock_invoke_resources`, plus IAM policy simulation |

A `us.` inference profile can route a call to another region, so the trail is multi-region and the stage 4 policy allows the profile ARN plus the backing foundation model ARN in every region the profile covers.

## Destroy

```bash
terraform destroy
```

Cheap, but the stage 0 endpoint is unauthenticated and hands live credentials to anyone who finds it. Do not leave it up between sessions.
