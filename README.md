# regtech EKS infrastructure provisioned with Terraform 
# This can be deployed in two ways, from either a VM/PC or from Githubactions workflow

# Deploying from VM or PC

- `clone the reposiroty`
- `edit terraform files to your prefrence: like region, backend, number of nodes etc`



### Install AWS CLI 

As the first step, you need to install AWS CLI as we will use the AWS CLI (`aws configure`) command to connect Terraform with AWS in the next steps.

Follow the below link to Install AWS CLI.
```
https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
```

### Install Terraform

Next, Install Terraform using the below link.
```
https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
```

### Connect Terraform with AWS

Its very easy to connect Terraform with AWS. Run `aws configure` command and provide the AWS Security credentials as shown in the video.

### Initialize Terraform

Clone the repository and Run `terraform init`. This will intialize the terraform environment for you and download the modules, providers and other configuration required.

### format and validate the terraform configurations

Run `terraform fmt`

Run `terraform validate`


### Optionally review the terraform configuration

Run `terraform plan` to see the configuration it creates when executed.

### Finally, Apply terraform configuation to create EKS cluster with VPC 

`terraform apply`

# Deploy from GitHub Actions workflow (recommended)

1. Fork the repository
2. Clone your forked repository
3. Create the following secrets in your GitHub repository:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
4. Edit the Terraform files as needed if needed
5. run `terraform fmt`
6. run `terraform validate`
5. Commit and push your changes to the main branch
6. Go to the Actions tab in your GitHub repository
7. click on the "Regtech-Infrastructure" workflow

To do that click on Actions

![alt text](<Screenshot 2024-09-07 at 17.05.21.png>)

Click on Regtech-Infrastructure you use the drop down to choose to plan, apply or destroy

![alt text](<Screenshot 2024-09-07 at 17.06.23.png>)

you can have options

![alt text](<Screenshot 2024-09-07 at 17.07.06.png>)


# on success plan, you goto same place and select apply and on sucesss you will get the image below

![alt text](<Screenshot 2024-09-07 at 17.35.13.png>)

# Regtech EKS Infrastructure with Graviton and Karpenter

This infrastructure can be deployed in two ways:
1. From a VM/PC
2. From GitHub Actions workflow (recommended)

## Quick Start - VM/PC Deployment

### Prerequisites
- AWS CLI installed and configured
- kubectl installed
- Terraform installed
- An AWS account with appropriate permissions

### Installation Steps

1. Install AWS CLI:
```
https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
```

2. Install Terraform:
```
https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
```

3. Clone and Configure:
```bash
# Clone repository
git clone <repository-url>

# Initialize Terraform
terraform init

# Format and validate
terraform fmt
terraform validate

# Deploy infrastructure
AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY terraform apply
```

## GitHub Actions Deployment

1. Fork the repository
2. Create GitHub secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
3. Edit Terraform files if needed
4. Push changes to main branch
5. Use Actions tab to deploy

## Post-Deployment Setup

### Connect to Cluster
```bash
# Verify cluster status
aws eks describe-cluster --region <your-region> --name <cluster-name> --query "cluster.status"

# Configure kubectl
aws eks update-kubeconfig --region <your-region> --name <cluster-name>

# Enable public/private access
aws eks update-cluster-config \
  --region <your-region> \
  --name <cluster-name> \
  --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true
```

### Create Namespace and RBAC
```bash
# Create namespace
kubectl create ns <your-namespace>
```

Create the following YAML files and apply them:

1. Service Account:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <name-of-app>
  namespace: <your-namespace>
```

2. Role:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: <your-namespace>
rules:
  - apiGroups:
        - ""
        - apps
        - autoscaling
        - batch
        - extensions
        - policy
        - rbac.authorization.k8s.io
    resources:
      - pods
      - secrets
      # [other resources as in original]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

3. Role Binding:
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-rolebinding
  namespace: <your-namespace>
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: app-role
subjects:
- namespace: webapps
  kind: ServiceAccount
  name: <name-of-app>
```

## Testing Karpenter with Graviton

### Deploy Test Application
```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
name: graviton-test
spec:
  replicas: 3
  selector:
    matchLabels:
      app: graviton-test
  template:
    metadata:
      labels:
        app: graviton-test
    spec:
      nodeSelector:
        kubernetes.io/arch: arm64
      containers:
      - name: nginx
        image: nginx:latest
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
EOF
```

### Monitor Deployment
```bash
# Watch nodes
kubectl get nodes -w

# Check Karpenter logs
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f

# Check pods
kubectl get pods -o wide
```

### Scaling Test
```bash
# Scale deployment
kubectl scale deployment graviton-test --replicas=10

# Watch node provisioning
kubectl get nodes -w
```

## Karpenter Configuration

Configured Graviton instance types:
- t4g.small
- t4g.medium
- c6g.large
- m6g.large

Settings:
- Architecture: arm64 (Graviton)
- Capacity types: spot and on-demand
- Resource limits:
  - CPU: 100
  - Memory: 100Gi

## Troubleshooting

1. Check Karpenter status:
```bash
kubectl get all -n karpenter
```

2. View logs:
```bash
kubectl logs -n karpenter -l app.kubernetes.io/name=karpenter -f
```

3. Check events:
```bash
kubectl get events --sort-by='.metadata.creationTimestamp'
```

## Cleanup

1. Remove test deployment:
```bash
kubectl delete deployment graviton-test
```

2. Destroy infrastructure:
```bash
AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY terraform destroy
```

## Security Considerations

- Regularly rotate AWS credentials
- Monitor node access patterns
- Review Karpenter logs
- Keep Karpenter and EKS versions updated
- Follow AWS security best practices

The infrastructure is now ready to receive applications! Proceed to the CICD pipeline to deploy your applications to this infrastructure.