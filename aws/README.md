# AWS Cloud-Native ML Inference Pipeline – Ingestion Layer

This repository contains a serverless ingestion system built on AWS using Terraform. It is designed to act as the entry point to a real-time machine learning inference platform. Incoming JSON events are accepted via an HTTP API, processed using AWS Lambda, and stored securely in Amazon S3. The system is designed for scalability, observability, and automation using Infrastructure as Code.

## Technologies Used

- Terraform (Infrastructure as Code)
- AWS Lambda (event processing)
- Amazon API Gateway (HTTP API)
- Amazon S3 (event storage)
- AWS IAM (role-based permissions)
- Amazon CloudWatch (logs and observability)

## Project Structure

- `terraform/` – Contains all Terraform configuration files
- `src/` – Lambda function source code and zipped deployment packages
- `ml-model/` – (Reserved for future model deployment or SageMaker integration)
- `ci-cd/` – (Reserved for GitHub Actions or deployment automation)
- `observability/` – (Reserved for metrics, dashboards, and tracing)

## Deployment Instructions

### Prerequisites

- AWS CLI installed and configured (`aws configure`)
- Terraform installed (v1.3 or higher)
- Python 3.11 for the Lambda runtime

### Steps

1. Package the Lambda function:

    ```bash
    cd src
    zip lambda_function_payload.zip lambda_function.py
    ```

2. Initialize and apply Terraform:

    ```bash
    cd ../terraform
    terraform init
    terraform plan
    terraform apply
    ```

## Testing the API

Once deployed, Terraform will output the API Gateway URL.

Use curl to test the endpoint:

```bash
curl -X POST https://<your-api-id>.execute-api.<region>.amazonaws.com/ingest \
     -H "Content-Type: application/json" \
     -d '{"message": "hello"}'

#Expected responnse:

{"message": "Event stored", "key": "event-<timestamp>.json"}


Logs and Monitoring
Event JSON payloads are stored in your ml-inference-events-* S3 bucket

CloudWatch Logs capture Lambda execution details

Permissions and environment variables are managed via Terraform

License
MIT License © vijs29
