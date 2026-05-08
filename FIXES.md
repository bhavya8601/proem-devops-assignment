# FIXES.md

Document every issue you find and fix in this file.

I approached the assignment in this order:

1. First, I made the actual two-service system work with docker compose up.
2. Then I removed unsafe hardcoded secrets and moved them to environment-based configuration.
3. After that, I improved Docker, CI/CD, Terraform, and Kubernetes configuration.
4. Finally, I added a few self-initiated improvements to make the project cleaner and safer.

---

## Fix 1: Service B could not reach Service A in Docker Compose

*What was wrong:*

service-b was configured to call Service A using:

text
http://localhost:5000


Inside Docker Compose, each service runs in its own container. From inside the service-b container, localhost points to service-b itself, not to service-a.

*Why it is a problem:*

The main requirement of the assignment was that docker compose up should start both services and Service B should successfully poll Service A. With localhost, Service B could not reliably reach the Flask API.

*How I fixed it:*

I changed the Service A URL in docker-compose.yml to use Docker Compose service discovery:

text
http://service-a:5000


Docker Compose creates an internal network where services can communicate using their service names.

*What could go wrong if left unfixed:*

Both containers might start, but the system would still be broken because the worker would continuously fail to reach the API.

---

## Fix 2: Hardcoded secrets were present in container configuration

*What was wrong:*

The original configuration contained hardcoded secret-like values such as:

text
SECRET_KEY=supersecret123
DB_PASSWORD=admin1234


These values were present in files that are committed to Git.

*Why it is a problem:*

Secrets should not be committed to source control or baked into Docker images. Even if these are sample values, it is a bad practice and could become dangerous if real credentials are added later.

*How I fixed it:*

I removed hardcoded values from the Dockerfile and changed docker-compose.yml to read them from environment variables:

yaml
SECRET_KEY: ${SECRET_KEY:-}
DB_PASSWORD: ${DB_PASSWORD:-}


I also added .env.example to document the expected variables without committing real secrets.

*What could go wrong if left unfixed:*

Real secrets could accidentally be exposed in GitHub, Docker image layers, CI logs, or shared repositories.

---


## Fix 3: Docker Compose did not wait for Service A to become healthy

*What was wrong:*

The original Compose file used depends_on, but basic depends_on only controls container startup order. It does not wait until the application inside the container is ready.

*Why it is a problem:*

Service B could start before Service A was ready to accept requests. This creates a startup race condition.

*How I fixed it:*

I added a healthcheck for Service A using the existing /health endpoint and configured Service B to wait until Service A is healthy before starting.

*What could go wrong if left unfixed:*

The worker could fail during startup depending on timing, machine speed, or container startup delay.

---

## Fix 4: Service A was running as root and using Flask development server

*What was wrong:*

The original Service A Dockerfile ran as root and started the app using:

text
python app.py


That runs the Flask development server.

*Why it is a problem:*

Containers should avoid running as root unless absolutely required. Also, Flask's development server is not suitable for production-style deployments.

*How I fixed it:*

I updated the Service A Dockerfile to:

- use a smaller python:3.11-slim image
- install dependencies with --no-cache-dir
- improve Docker layer caching by copying requirements.txt before the full source
- create and use a non-root user
- run the app with Gunicorn

*What could go wrong if left unfixed:*

A compromised app would run with unnecessary root privileges. The Flask development server could also behave poorly under production-like traffic.

---

## Fix 5: Service B was running as root and using a larger base image

*What was wrong:*

The original Service B Dockerfile used the full Node image and ran the worker as root.

*Why it is a problem:*

The worker does not need root privileges. Larger images also increase build time, image size, and attack surface.

*How I fixed it:*

I updated the Service B Dockerfile to:

- use node:18-slim
- copy package.json before the full source for better Docker caching
- run the process as the built-in non-root node user

*What could go wrong if left unfixed:*

A vulnerability in the Node app or dependency would have more impact because the process would run with unnecessary privileges.

---

## Fix 6: GitHub Actions workflow contained hardcoded credentials

*What was wrong:*

The original workflow contained hardcoded Docker credentials:

text
docker login -u myuser -p mypassword123


It also used latest image tags and included unsafe SSH deployment logic.

*Why it is a problem:*

CI/CD workflows are part of the codebase and should never contain passwords or tokens. The latest tag also makes deployments hard to track because the same tag can point to different images over time.

*How I fixed it:*

I changed the workflow to use GitHub Secrets and Variables.

Secrets used:

text
SECRET_KEY
DB_PASSWORD
DOCKERHUB_USERNAME
DOCKERHUB_TOKEN


Variables used:

text
SERVICE_A_IMAGE
SERVICE_B_IMAGE


The workflow now validates the Docker Compose setup automatically and keeps Docker image publishing manual through workflow_dispatch.

*What could go wrong if left unfixed:*

Credentials could be leaked publicly. Deployments could also become unpredictable because latest does not clearly identify which commit is running.

---

## Fix 7: CI did not validate the actual Docker Compose system

*What was wrong:*

The workflow was focused on building and pushing an image, but it did not properly validate that the two-service system worked together.

*Why it is a problem:*

The main assignment requirement is not only that images build, but that service-b can successfully poll service-a.

*How I fixed it:*

I added CI steps to:

- validate the Docker Compose file
- build the services
- start the services
- check Service A's /health endpoint
- verify that Service B logs successful polling from Service A

*What could go wrong if left unfixed:*

A broken Compose setup could still pass CI if only image build steps were checked.

---

## Fix 8: Terraform provider had hardcoded AWS credentials

*What was wrong:*

The Terraform provider block contained hardcoded AWS access key and secret key values.

*Why it is a problem:*

Cloud credentials should never be committed to Git. Terraform should use secure credential sources such as AWS CLI profiles, environment variables, or IAM roles.

*How I fixed it:*

I removed the hardcoded credentials from terraform/main.tf. The AWS provider now uses the standard AWS credential chain.

*What could go wrong if left unfixed:*

If real credentials were committed, someone could use them to access or modify AWS resources.

---

## Fix 9: Terraform security group allowed all inbound TCP traffic

*What was wrong:*

The original security group allowed all TCP ports from anywhere:

text
0.0.0.0/0 on ports 0-65535


*Why it is a problem:*

This exposes far more than necessary. Security groups should follow least privilege and only allow required traffic.

*How I fixed it:*

I restricted inbound traffic to the application port and made the allowed CIDR ranges configurable using Terraform variables.

*What could go wrong if left unfixed:*

Any service running on the instance could be exposed to the public internet, increasing the risk of compromise.

---

## Fix 10: Terraform configuration was not reusable or easy to maintain

*What was wrong:*

The original Terraform configuration had hardcoded values such as region, AMI, instance type, and ports.

*Why it is a problem:*

Hardcoded infrastructure values make the configuration harder to reuse across environments. Hardcoded AMI IDs can also become outdated or fail in other regions.

*How I fixed it:*

I added:

- variables.tf for reusable input values
- outputs.tf for useful EC2 outputs
- dynamic Amazon Linux AMI lookup
- resource tags
- IMDSv2 enforcement
- encrypted root volume

*What could go wrong if left unfixed:*

The infrastructure code would be harder to reuse, less secure, and more likely to break over time.

---

## Fix 11: Terraform was not validated in CI

*What was wrong:*

Terraform files existed in the repository, but CI did not check whether the Terraform code was formatted or valid.

*Why it is a problem:*

Terraform errors should be caught early before someone tries to deploy infrastructure manually.

*How I fixed it:*

I added a Terraform validation job in GitHub Actions that runs:

text
terraform fmt -check
terraform init -backend=false
terraform validate


I did not add terraform apply because applying infrastructure should require real AWS credentials and explicit approval.

*What could go wrong if left unfixed:*

Broken Terraform configuration could remain in the repository unnoticed.

---

## Fix 12: Kubernetes deployment used a mutable image tag

*What was wrong:*

The Kubernetes deployment used:

text
latest


*Why it is a problem:*

The latest tag is mutable. The same manifest can deploy different image versions at different times, which makes rollback and debugging harder.

*How I fixed it:*

I changed the manifest to use a versioned image reference. In the workflow, the Kubernetes deploy job can update the deployment to use the exact image tag built from the current Git commit SHA.

*What could go wrong if left unfixed:*

It would be difficult to know exactly which version of the app is running in Kubernetes.

---

## Fix 13: Kubernetes deployment lacked readiness and liveness probes

*What was wrong:*

The original Kubernetes deployment did not define readiness or liveness probes.

*Why it is a problem:*

Without probes, Kubernetes cannot reliably know when the app is ready to receive traffic or when it should restart a broken container.

*How I fixed it:*

I added readiness and liveness probes using the existing /health endpoint.

*What could go wrong if left unfixed:*

Kubernetes could send traffic to a pod that is not ready or fail to restart a stuck container.

---

## Fix 14: Kubernetes deployment lacked proper resource limits and security context

*What was wrong:*

The original Kubernetes manifest had resource requests but no limits. It also did not define strong container security settings.

*Why it is a problem:*

Without limits, a container can consume more CPU or memory than expected. Without a security context, it may run with more privileges than necessary.

*How I fixed it:*

I added:

- CPU and memory limits
- runAsNonRoot
- runAsUser
- allowPrivilegeEscalation: false
- dropped Linux capabilities

*What could go wrong if left unfixed:*

The pod could consume excessive resources or run with unnecessary privileges.

---

## Fix 15: Kubernetes secrets were not handled through Secret references

*What was wrong:*

Runtime values such as SECRET_KEY and DB_PASSWORD should not be written directly inside Kubernetes manifests.

*Why it is a problem:*

Kubernetes YAML files are usually committed to Git. Putting secret values directly in those files would expose them.

*How I fixed it:*

I updated the deployment to read these values from a Kubernetes Secret named:

text
service-a-secrets


The manual Kubernetes deployment job can create or update this secret using GitHub Secrets.

*What could go wrong if left unfixed:*

Real secret values could be committed to Git or exposed in deployment manifests.

---


## Self-initiated Improvements



### Improvement 1: Added .dockerignore files

I added .dockerignore files for both services.

This keeps unnecessary local files such as .env, cache files, virtual environments, node_modules, and Git metadata out of Docker build contexts.

This makes Docker builds cleaner and reduces the chance of accidentally copying sensitive or unnecessary files into images.

---

### Improvement 2: Improved Docker image quality

I improved both Dockerfiles by using slimmer base images, better dependency installation order, and non-root users.

This makes the images smaller, safer, and more production-friendly.

---

### Improvement 3: Added safer CI/CD behavior

I changed the workflow so normal pushes validate the project but do not automatically publish or deploy everything.

Publishing and Kubernetes deployment are manual/gated actions. This is safer for an assignment and closer to how I would handle deployment-sensitive steps in a real project.

---

## Validation Performed

I tested the main application locally using:

bash
docker compose up --build


I confirmed that:

- Service A starts successfully
- Service A exposes /health
- Service A exposes /data
- Service B successfully polls Service A
- Service B logs the response from Service A

I also confirmed that the old hardcoded values were removed from the active configuration and replaced with environment-based configuration.