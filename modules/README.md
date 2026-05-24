# Terraform Modules Directory

This directory will contain reusable modules for the Webinar & Certification Management System infrastructure. Each module should be placed in its own subdirectory (e.g., `vpc`, `alb`, `ec2_asg`, `s3`, `cloudfront`, `rds`, `dynamodb`, `iam`, `ses`).

## Example Structure

- vpc/
- alb/
- ec2_asg/
- s3/
- cloudfront/
- rds/
- dynamodb/
- iam/
- ses/

Each module should have its own `main.tf`, `variables.tf`, and `outputs.tf` files as appropriate.

---

This structure will help keep your Terraform codebase organized, maintainable, and scalable for academic and production use.
