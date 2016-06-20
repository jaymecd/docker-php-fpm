#!/bin/sh

set -e

echo "* Entrypoint hook for '$@'"

PHP_INI_FILE="${PHP_INI_DIR}/php.ini"

sed -i "/^;*memory_limit\s*=/c\memory_limit = ${PHP_INI_MEMORY_LIMIT}" ${PHP_INI_FILE}
sed -i "/^;*date.timezone\s*=/c\date.timezone = ${PHP_INI_TIMEZONE}" ${PHP_INI_FILE}
sed -i "/^;*xdebug.remote_port\s*=/c\xdebug.remote_port = ${XDEBUG_REMOTE_PORT}" ${PHP_INI_FILE}

if [ -z "${NEWRELIC_LICENSE}" ]; then
	echo "* NewRelic: disabled"

	sed -i "/^;*newrelic.enabled\s*=/c\;newrelic.enabled =" ${PHP_INI_FILE}
	sed -i "/^;*newrelic.license\s*=/c\;newrelic.license =" ${PHP_INI_FILE}
	sed -i "/^;*newrelic.appname\s*=/c\;newrelic.appname =" ${PHP_INI_FILE}
else
	echo "* NewRelic: enabled (${NEWRELIC_APPNAME})"

	sed -i "/^;*newrelic.enabled\s*=/c\newrelic.enabled = true" ${PHP_INI_FILE}
	sed -i "/^;*newrelic.license\s*=/c\newrelic.license = '${NEWRELIC_LICENSE}'" ${PHP_INI_FILE}
	sed -i "/^;*newrelic.appname\s*=/c\newrelic.appname = '${NEWRELIC_APPNAME}'" ${PHP_INI_FILE}
fi

exec "$@"
