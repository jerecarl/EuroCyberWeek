# WebGoat Infrastructure (Terraform)

Showcase the [WebGoat](https://github.com/WebGoat/WebGoat) application in an AKS cluster, protected by an Azure Application Gateway (WAF).

```bash
az login
terraform init
terraform apply -var 'subscription_id=XXXX' -auto-approve
```
