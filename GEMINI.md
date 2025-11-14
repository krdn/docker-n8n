# GEMINI.md

## Project Overview

This project provides a production-ready, enterprise-grade n8n workflow automation platform using Docker. It is architected in a queue-based microservices mode to ensure high availability, scalability, and stability.

The core technologies used are:
- **n8n:** The workflow automation tool. The project uses a main instance for the UI and API, and a separate worker instance for executing workflows.
- **Docker and Docker Compose:** For containerizing and orchestrating the services.
- **PostgreSQL:** As the database for storing workflow definitions, execution history, and credentials.
- **Redis:** As the message broker for the Bull queue, which manages the distribution of workflow executions to the workers.
- **Nginx:** As a reverse proxy for SSL/TLS termination and secure access to the n8n instance.

The system is designed with a strong focus on security, with multiple layers of protection including network isolation, SSL/TLS encryption, and restricted port bindings. It also features a comprehensive automation system for backups and updates, managed by systemd timers.

## Building and Running

The project is managed using Docker Compose. The main commands are:

### Service Management

- **Start services in the background:**
  ```bash
  docker-compose up -d
  ```

- **Stop all services:**
  ```bash
  docker-compose down
  ```

- **Check the status of the containers:**
  ```bash
  docker-compose ps
  ```

- **View real-time logs for a specific service (e.g., n8n):**
  ```bash
  docker-compose logs -f n8n
  ```

- **Restart a specific service:**
  ```bash
  docker-compose restart n8n
  ```

### Automation

The project includes scripts for automated backups and updates, which are managed by systemd timers.

- **Enable the automation (install systemd timers):**
  ```bash
  sudo bash ENABLE_AUTOMATION.sh
  ```

- **Check the status of the automation timers:**
  ```bash
  sudo systemctl list-timers n8n-*
  ```

- **Run a manual backup:**
  ```bash
  ./scripts/backup.sh
  ```

- **Run a manual update:**
  ```bash
  ./scripts/update.sh
  ```

## Development Conventions

Based on the project structure and scripts, the following conventions are in place:

- **Configuration as Code:** All service configurations are defined in `docker-compose.yml`, and environment-specific settings are managed in the `.env` file.
- **Immutable Infrastructure:** The services are containerized and should not be modified directly. Changes should be made to the `docker-compose.yml` file or the environment variables and then redeployed.
- **Automated Backups:** Daily full backups and weekly database backups are performed automatically. The backup script (`scripts/backup.sh`) is the single source of truth for the backup process.
- **Automated Updates:** The `scripts/update.sh` script provides a safe and automated way to update the n8n application, including a rollback mechanism.
- **Security First:** The project follows a "defense in depth" security strategy, with multiple layers of security. This includes network security, SSL/TLS encryption, and secure by default configurations.
- **Detailed Documentation:** The project is well-documented, with a comprehensive `README.md` file and several other guides for specific tasks.
