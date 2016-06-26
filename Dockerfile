FROM php:7.0-fpm-alpine

MAINTAINER Nikolai Zujev <nikolai.zujev@gmail.com> 

ENV PHP_EXTENTIONS="opcache bcmath bz2 ctype gd fileinfo intl mcrypt pdo_mysql sockets xsl zip" \
    PECL_EXTENTIONS="apcu timezonedb xdebug" \
    IGBINARY_VERSION=master \
    MEMCACHED_VERSION=php7 \
    REDIS_VERSION=3.0.0 \
    GEOIP_VERSION=1.1.0 \
    PHP_INI_TIMEZONE=UTC \
    PHP_INI_MEMORY_LIMIT=512M \
    XDEBUG_REMOTE_PORT=9000 \
    NEWRELIC_LICENSE="" \
    NEWRELIC_APPNAME=""

RUN set -xe \
  && PECL_EXCLUDE_REGEX='igbinary|memcached|redis' \
  && PECL_EXTENTIONS="$(echo ${PECL_EXTENTIONS} | tr ' ' '\n' | egrep -v ${PECL_EXCLUDE_REGEX} | xargs echo)" \
  && NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
  && apk upgrade -U \
  && apk add --no-cache --virtual .build-deps \
      $PHPIZE_DEPS \
      libxml2-dev \
      libxslt-dev \
      bzip2-dev \
      zlib-dev \
      icu-dev \
      libmcrypt-dev \
      freetype-dev \
      libxpm-dev \
      libpng-dev \
      libwebp-dev \
      libjpeg-turbo-dev \
      libmemcached-dev \
      geoip-dev \
  && for EXT in ${PHP_EXTENTIONS}; do docker-php-ext-install -j${NPROC} ${EXT}; done \
  && for EXT in ${PECL_EXTENTIONS}; do pecl install ${EXT} && docker-php-ext-enable ${EXT}; done \
  && curl -fsSL -D - -o /tmp/ext-igbinary.tgz https://github.com/igbinary/igbinary7/archive/${IGBINARY_VERSION}.tar.gz \
    && tar zxpf /tmp/ext-igbinary.tgz -C /tmp \
    && cd /tmp/igbinary7-${IGBINARY_VERSION} \
    && phpize && ./configure \
    && make -j${NPROC} && make install \
    && docker-php-ext-enable igbinary \
  && curl -fsSL -o /tmp/ext-memcached.tgz https://github.com/php-memcached-dev/php-memcached/archive/${MEMCACHED_VERSION}.tar.gz \
    && tar zxpf /tmp/ext-memcached.tgz -C /tmp \
    && cd /tmp/php-memcached-${MEMCACHED_VERSION} \
    && phpize && ./configure --disable-memcached-sasl --enable-memcached-igbinary --enable-memcached-json \
    && make -j${NPROC} && make install \
    && docker-php-ext-enable memcached \
  && curl -fsSL -o /tmp/ext-redis.tgz https://github.com/phpredis/phpredis/archive/${REDIS_VERSION}.tar.gz \
    && tar zxpf /tmp/ext-redis.tgz -C /tmp \
    && cd /tmp/phpredis-${REDIS_VERSION} \
    && phpize && ./configure --enable-redis-igbinary \
    && make -j${NPROC} && make install \
    && docker-php-ext-enable redis \
  && curl -fsSL -o /tmp/ext-geoip.tgz https://pecl.php.net/get/geoip-${GEOIP_VERSION}.tgz \
    && tar zxpf /tmp/ext-geoip.tgz -C /tmp \
    && cd /tmp/geoip-${GEOIP_VERSION} \
    && curl -fsSL -O https://raw.githubusercontent.com/gplessis/dotdeb-php-geoip/jessie-php70/debian/patches/0001-add-fix-for-PHP7.patch \
    && patch -p2 < 0001-add-fix-for-PHP7.patch \
    && phpize && ./configure \
    && make -j${NPROC} && make install \
    && docker-php-ext-enable geoip \
  && curl -fsSL -o /tmp/composer-setup.php https://getcomposer.org/installer \
    && php /tmp/composer-setup.php -- --install-dir=/usr/local/bin --filename=composer \
  && RUN_DEPS="$( \
    scanelf --needed --nobanner --recursive /usr/local \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | sort -u \
      | xargs -r apk info --installed \
      | sort -u \
    )" \
  && apk add --no-cache --virtual .php-rundeps ${RUN_DEPS} \
  && apk del .build-deps \
  && rm -rf /tmp/* /usr/local/etc/php-fpm.*

COPY config/ /usr/local/etc/
COPY entrypoint.sh /usr/local/bin/entrypoint

ENTRYPOINT ["entrypoint"]

CMD ["php-fpm"]
