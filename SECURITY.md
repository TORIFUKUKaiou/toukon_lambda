# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it by emailing the maintainers directly. Please do not report security vulnerabilities through public GitHub issues.

## Security Features

- No hardcoded credentials or API keys
- Dynamic AWS credential resolution
- Proper secret management through environment variables
- Container security best practices

## Environment Variables

This project uses the following environment variables:

- `AWS_REGION` - AWS region (default: ap-northeast-1)
- `AWS_LAMBDA_RUNTIME_API` - Lambda Runtime API endpoint (set automatically by AWS)
- `_X_AMZN_TRACE_ID` - X-Ray trace ID (set automatically by AWS)

Never commit actual values for these variables to version control.
