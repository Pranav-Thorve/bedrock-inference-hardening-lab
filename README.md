# Bedrock inference hardening lab

Broken-by-design internal LLM inference API on AWS. Terraform deploys the **starting, insecure** state. Fix the three failures yourself.

Not production. Use a throwaway account. Tear it down when you are done.

## What gets deployed (broken)

Linear path: client → API Gateway → Lambda → Amazon Bedrock.

| Failure | Broken state |
| --- | --- |
| 1. Over-broad Lambda role | `bedrock:*` and `logs:*` on `*` |
| 2. Throttle gap | REST API with no usage plan, no API key, no WAF, `authorization = NONE` |
| 3. Exception leak | 500 responses include `str(e)` and a dump of `os.environ` (live Lambda AWS keys) |

Happy path: `POST /lab/invoke` with `{"prompt":"..."}` calls Claude Haiku via Bedrock.

Crash path (Failure 3): `{"prompt":"__crash__"}` or invalid JSON.

## How Terraform knows your AWS account

These files do **not** take an account ID. They use the AWS CLI identity already on your machine.

```bash
aws configure --profile lab
export AWS_PROFILE=lab
export AWS_REGION=us-east-1
aws sts get-caller-identity
terraform init
terraform apply
```

Enable Bedrock model access in that region for the model in `variables.tf` before you expect a 200 from inference. The crash path works even without model access.

## Invoke

```bash
INVOKE_URL=$(terraform output -raw invoke_url)

# working inference (needs Bedrock model access)
curl -sS -X POST "$INVOKE_URL" \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"Say hello in one sentence."}'

# Failure 3: leaked env / credentials
curl -sS -X POST "$INVOKE_URL" \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"__crash__"}'
```

## Destroy

```bash
export AWS_PROFILE=lab
export AWS_REGION=us-east-1
terraform destroy
```
