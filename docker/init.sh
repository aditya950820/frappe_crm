#!/bin/bash

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
while ! mysqladmin ping -h"mariadb" -P"3306" --silent; do
    sleep 2
done
echo "MariaDB is ready!"

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
while ! redis-cli -h redis ping > /dev/null 2>&1; do
    sleep 2
done
echo "Redis is ready!"

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, starting services..."
    cd frappe-bench
    bench start
else
    echo "Creating new bench..."
    
    # Initialize bench
    bench init --skip-redis-config-generation frappe-bench --version version-15
    
    cd frappe-bench
    
    # Configure database and Redis connections
    bench set-mariadb-host mariadb
    bench set-redis-cache-host redis://redis:6379
    bench set-redis-queue-host redis://redis:6379
    bench set-redis-socketio-host redis://redis:6379
    
    # Remove redis, watch from Procfile
    sed -i '/redis/d' ./Procfile
    sed -i '/watch/d' ./Procfile
    
    # Get the CRM app
    bench get-app crm --branch main
    
    # Create site
    bench new-site crm.localhost \
        --force \
        --mariadb-root-password 123 \
        --admin-password admin \
        --no-mariadb-socket
    
    # Install CRM app
    bench --site crm.localhost install-app crm
    bench --site crm.localhost set-config developer_mode 1
    bench --site crm.localhost set-config mute_emails 1
    bench --site crm.localhost set-config server_script_enabled 1
    bench --site crm.localhost clear-cache
    bench use crm.localhost
    
    echo "Bench setup completed successfully!"
fi

# Start the bench
echo "Starting Frappe bench..."
bench start