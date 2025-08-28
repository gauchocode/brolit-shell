# Brolit Shell Test Environment

This Docker environment is designed to test the borgmatic template update functionality in isolation.

## Prerequisites

- Docker
- Docker Compose

## Setup

1. Create the necessary directories:
```bash
mkdir -p tests/test-environment/{config,data}
```

2. Create a sample brolit configuration:
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

3. Start the environment:
```bash
cd tests/test-environment
docker-compose up -d
```

## Usage

Access the container:
```bash
docker exec -it brolit-test-env bash
```

Test the borgmatic template update:
```bash
# Navigate to brolit-shell directory
cd /brolit-shell

# Run the update script
bash libs/borg_storage_controller.sh borg_update_templates
```

## Stopping the Environment

```bash
cd tests/test-environment
docker-compose down
