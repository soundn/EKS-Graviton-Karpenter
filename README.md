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

# goto the EKS console After a successful workflow Apply action and click on create access to the user this will take you to where you attach the following policy  
1. AmazonEKSClusterPolicy
2. AmazonEKSWorkerNodePolicy
3. AmazonEKSServicePolicy
4. AmazonEKS_CNI_Policy
## Create Namespace and RBAC for application 
# Access cluster from any cli where AWScli is installed and configured to the account and region or you can use AWS cloudshell of the region.

1. confirm that your cluster is active 
    Run `aws eks describe-cluster --region <your region> --name <cluster-name> --query "cluster.status"`
2. to connect to cluster and carry out kubectl commands
    Run `aws eks update-kubeconfig --region <your region> --name <cluster-name>`
3. to enable access to the cluster
    Run 
    ```
    aws eks update-cluster-config \
    --region <your region> \
    --name <cluster-name> \
    --resources-vpc-config endpointPublicAccess=true,endpointPrivateAccess=true
    ```

# Create Namespace, Service Account, Role & Assign that role
    ```
    Run kubectl create ns <your-namespace>
    ```
# For the yaml codes below, copy and create the file.yml and Run with `kubectl apply -f file.yml`

# Creating Service Account


```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <name-of-app>
  namespace: <your-namespace>
```

### Create Role 


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
      - componentstatuses
      - configmaps
      - daemonsets
      - deployments
      - events
      - endpoints
      - horizontalpodautoscalers
      - ingress
      - jobs
      - limitranges
      - namespaces
      - nodes
      - pods
      - persistentvolumes
      - persistentvolumeclaims
      - resourcequotas
      - replicasets
      - replicationcontrollers
      - serviceaccounts
      - services
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

### Bind the role to service account


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

## Now the infrastructre and name space is ready to recieve the app!!!
## We heard over to the CICD pipleline to deploy a sample game app to this infrastructure.
# EKS-Graviton-Karpenter
