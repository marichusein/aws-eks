# AWS EKS Terraform Configuration

![AWS EKS](https://img.shields.io/badge/AWS-EKS-orange) ![Terraform](https://img.shields.io/badge/Terraform-%5E0.12-blueviolet)

This Terraform project automates the provisioning of an Amazon EKS (Elastic Kubernetes Service) cluster in AWS. It creates the necessary AWS resources, including a VPC, public and private subnets, NAT gateway, EKS cluster, and an autoscaling group for worker nodes.

## Prerequisites

- Terraform (>= 0.12)
- AWS CLI configured with necessary permissions
- AWS IAM user or role with appropriate permissions for provisioning resources

## Usage

1. Clone the repository:

```bash
git clone https://github.com/marichusein/aws-eks.git
cd aws-eks
```

2. Initialize Terraform:

```bash
terraform init
```

3. Customize the variables (if needed):

Edit the `variables.tf` file to set your desired values for the EKS cluster, AWS region, and other parameters.

4. Deploy the infrastructure:

```bash
terraform apply
```

5. Review the planned changes and confirm the deployment.

6. Wait for the EKS cluster to be created.

7. Configure `kubectl` to interact with the EKS cluster:

```bash
aws eks update-kubeconfig --name <cluster_name> --region <aws_region>
```

Replace `<cluster_name>` and `<aws_region>` with the appropriate values used in the Terraform variables.

8. Verify the EKS cluster and nodes:

```bash
kubectl get nodes
```

## Cleaning Up

To tear down the resources created by this Terraform configuration, run:

```bash
terraform destroy
```

## Contributing

We welcome contributions to improve this project. Feel free to open issues or submit pull requests!

## License

This project is licensed under the [MIT License](LICENSE).
