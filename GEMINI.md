# Gemini Code Assistant Context

This document provides context for the Gemini Code Assistant to understand the `rainforest-iot` project.

## Project Overview

This project is a production-grade IoT platform for Raspberry Pi 5, built on a 3-layer architecture using Ansible, Terraform, and Kubernetes.

*   **Layer 1 (Ansible):** Sets up the infrastructure, including a K3s Kubernetes cluster optimized for ARM64, system hardening with UFW and fail2ban, and kubeconfig management.
*   **Layer 2 (Terraform):** Deploys workloads, including Docker services like HomeAssistant, Pi-hole, and Homepage, as well as a Kubernetes monitoring stack with Prometheus, Grafana, and Loki.
*   **Layer 3 (Future):** Intended for custom application deployments and integrations.

## Building and Running

### 1. Infrastructure Setup (Ansible)

1.  **Configure Ansible Inventory:** Edit `ansible/inventory.yml` with your Raspberry Pi's IP address or hostname.
2.  **Run Ansible Playbook:**
    ```bash
    ansible-playbook -i ansible/inventory.yml ansible/site.yml
    ```

### 2. Workload Deployment (Terraform)

1.  **Configure Terraform:**
    *   Copy `terraform.tfvars.example` to `terraform.tfvars`.
    *   Edit `terraform.tfvars` with your desired configuration.
2.  **Create Docker Context:**
    ```bash
    docker context create raspberrypi-5 --docker "host=ssh://raspberrypi-5"
    ```
3.  **Deploy Workloads:**
    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

## Development Conventions

*   **Infrastructure as Code:** The project strictly follows the Infrastructure as Code (IaC) paradigm, with all infrastructure and workload definitions managed in version control.
*   **Modularity:** The Terraform code is highly modular, with each service defined in its own module. This promotes reusability and maintainability.
*   **Separation of Concerns:** The project maintains a clean separation between infrastructure (Ansible) and workloads (Terraform).
*   **Dependency Management:** The project uses `depends_on` and `time_sleep` resources in Terraform to manage dependencies between resources, ensuring that they are created in the correct order.
*   **Security:** The project incorporates several security best practices, such as running containers with no privileged access, setting resource limits, and using read-only Docker socket mounts.

## Key Files

*   `README.md`: The main entry point for understanding the project.
*   `main.tf`: The root Terraform file that defines the providers and modules.
*   `versions.tf`: Specifies the required versions for Terraform and the providers.
*   `variables.tf`: Defines the input variables for the Terraform configuration.
*   `terraform.tfvars.example`: An example of the `terraform.tfvars` file, which is used to provide user-specific values for the input variables.
*   `ansible/site.yml`: The main Ansible playbook that orchestrates the infrastructure setup.
*   `ansible/playbooks/k3s-install.yml`: The Ansible playbook that installs and configures the K3s Kubernetes cluster.
*   `modules/`: This directory contains the Terraform modules for each service.
