#!/usr/bin/env bash

set -e

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# Check first run: listen on all interfaces: 0.0.0.0
if [ ! -e /etc/.mariadb_firstrun ]; then
	echo "=============================first run============================="
	cat << EOF >> /etc/my.cnf.d/mariadb-server.cnf
	[mysqld]
	bind-address=0.0.0.0
	port=3307
	skip-networking=0
EOF
	touch /etc/.mariadb_firstrun
fi

# Check first mount
if [ ! -e /var/lib/mysql/.firstmount ]; then
	echo "Initializing MariaDB..."
	mysql_install_db --datadir=/var/lib/mysql --skip-test-db --user=mysql --group=mysql \
		--auth-root-authentication-method=socket

	echo "Starting MariaDB temporarily..."
	mysqld_safe &
	mysqld_pid=$!

	echo "Waiting for MariaDB to start..."
	mysqladmin ping -u root --silent --wait >/dev/null 2>/dev/null

	echo "Creating database: ${MYSQL_DATABASE}"

	# Show the SQL that will be executed
	echo "=== SQL to execute ==="
	cat << EOF
		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
		CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
		GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
		GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' WITH GRANT OPTION;
		FLUSH PRIVILEGES;
EOF

		echo "======================"

		cat << EOF | mysql --protocol=socket -u root
		CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
		CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
		GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
		GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' WITH GRANT OPTION;
		FLUSH PRIVILEGES;
EOF

	echo "Shutting down temporary MariaDB..."
	mysqladmin shutdown
	touch /var/lib/mysql/.firstmount
	echo "Initialization complete!"
fi

echo "Starting MariaDB in foreground..."
# Start MariaDB in foreground
exec mariadbd --user=mysql \
--datadir=/var/lib/mysql \
    --socket=/run/mysqld/mysqld.sock
