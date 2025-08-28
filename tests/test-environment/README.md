# Brolit Shell Test Environment

This Docker environment is designed to test the borgmatic template update functionality in isolation. It creates a clean Ubuntu environment with all dependencies installed and mounts the current brolit-shell codebase for testing.

## Prerequisites

- Docker
- Docker Compose

## Setup

1. Create the necessary directories:
```bash
mkdir -p tests/test-environment/config
```

2. Create a sample brolit configuration file:
```bash
cat > tests/test-environment/config/brolit_conf.json << 'EOL'
{
    "BACKUP_BORG_STATUS": "enabled",
    "BACKUP_BORG_USER": "testuser",
    "BACKUP_BORG_SERVER": "localhost",
    "BACKUP_BORG_PORT": "22",
    "BACKUP_BORG_GROUP": "test-group",
    "number_of_servers": 1
}
EOL
```

## Building and Starting the Environment

1. Navigate to the test environment directory:
```bash
cd tests/test-environment
```

2. Build and start the container:
```bash
docker-compose up -d --build
```

This will:
- Build the Docker image using the Dockerfile
- Install all required dependencies (borgbackup, borgmatic, yq, jq, etc.)
- Copy the current brolit-shell codebase into the container
- Start the container in detached mode

## Usage

1. Access the container:
```bash
docker exec -it brolit-test-env bash
```

2. Once inside the container, you can test the borgmatic template update:
```bash
# Navigate to brolit-shell directory
cd /brolit-shell

# Run the update script
bash libs/borg_storage_controller.sh borg_update_templates
```

3. You can also test other brolit-shell functionality as needed.

## Stopping the Environment

1. Stop and remove the container:
```bash
cd tests/test-environment
docker-compose down
```

2. To completely remove the container and image:
```bash
cd tests/test-environment
docker-compose down --rmi all
```

## Notes

- The environment always uses the current local version of brolit-shell
- Configuration files are mounted from the host, so changes to config/brolit_conf.json will be reflected in the container
- The container runs as root with password 'root'
- SSH is available on port 2222 (mapped to localhost:2222)
