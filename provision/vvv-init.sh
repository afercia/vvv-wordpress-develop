# Provision WordPress 5.0 Develop

# Make a database, if we don't already have one
echo -e "\nCreating database 'wp50_develop' (if it's not already there)"
mysql -u root --password=root -e "CREATE DATABASE IF NOT EXISTS wp50_develop"
mysql -u root --password=root -e "GRANT ALL PRIVILEGES ON wp50_develop.* TO wp@localhost IDENTIFIED BY 'wp';"
echo -e "\n DB operations done.\n\n"

# Nginx Logs
mkdir -p ${VVV_PATH_TO_SITE}/log
touch ${VVV_PATH_TO_SITE}/log/src.error.log
touch ${VVV_PATH_TO_SITE}/log/src.access.log
touch ${VVV_PATH_TO_SITE}/log/build.access.log
touch ${VVV_PATH_TO_SITE}/log/build.access.log

# Checkout, install and configure WordPress 5.0 branch via develop.svn
if [[ ! -d "${VVV_PATH_TO_SITE}/public_html" ]]; then
  echo "Checking out WordPress 5.0 branch. See https://develop.svn.wordpress.org/branches/5.0"
  noroot svn checkout "https://develop.svn.wordpress.org/branches/5.0/" "/tmp/wordpress-50"

  cd /tmp/wordpress-50/src/

  echo "Installing local npm packages for src.wp50-develop.test, this may take several minutes."
  noroot npm install --no-bin-links

  echo "Initializing grunt and creating build.wp50-develop.test, this may take several minutes."
  noroot grunt

  echo "Moving WordPress 5.0 develop to a shared directory, ${VVV_PATH_TO_SITE}/public_html"
  mv /tmp/wordpress-50 ${VVV_PATH_TO_SITE}/public_html

  cd ${VVV_PATH_TO_SITE}/public_html/src/
  echo "Creating wp-config.php for src.wp50-develop.test and build.wp50-develop.test."
  noroot wp core config --dbname=wp50_develop --dbuser=wp --dbpass=wp --quiet --extra-php <<PHP
// Match any requests made via xip.io.
if ( isset( \$_SERVER['HTTP_HOST'] ) && preg_match('/^(src|build)(.wp50-develop.)\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(.xip.io)\z/', \$_SERVER['HTTP_HOST'] ) ) {
    define( 'WP_HOME', 'http://' . \$_SERVER['HTTP_HOST'] );
    define( 'WP_SITEURL', 'http://' . \$_SERVER['HTTP_HOST'] );
} else if ( 'build' === basename( dirname( __FILE__ ) ) ) {
// Allow (src|build).wp50-develop.test to share the same Database
    define( 'WP_HOME', 'http://build.wp50-develop.test' );
    define( 'WP_SITEURL', 'http://build.wp50-develop.test' );
}

define( 'WP_DEBUG', true );
PHP

  echo "Installing src.wp50-develop.test."
  noroot wp core install --url=src.wp50-develop.test --quiet --title="WordPress 5.0 Develop" --admin_name=admin --admin_email="admin@local.test" --admin_password="password"
  cp /srv/config/wordpress-config/wp-tests-config.php ${VVV_PATH_TO_SITE}/public_html/
  cd ${VVV_PATH_TO_SITE}/public_html/

else

  echo "Updating WordPress 5.0 develop..."
  cd ${VVV_PATH_TO_SITE}/public_html/
  if [[ -e .svn ]]; then
    svn up
  else

    if [[ $(git rev-parse --abbrev-ref HEAD) == '5.0-branch' ]]; then
      git pull --no-edit git://develop.git.wordpress.org/ 5.0-branch
    else
      echo "Skip auto git pull on develop.git.wordpress.org since not on 5.0-branch"
    fi

  fi

  echo "Updating npm packages..."
  noroot npm install --no-bin-links &>/dev/null
fi

if [[ ! -d "${VVV_PATH_TO_SITE}/public_html/build" ]]; then
  echo "Initializing grunt in WordPress 5.0 develop... This may take a few moments."
  cd ${VVV_PATH_TO_SITE}/public_html/
  grunt
fi

ln -sf ${VVV_PATH_TO_SITE}/bin/develop_git /home/vagrant/bin/develop_git

cp -f "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf.tmpl" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"

if [ -n "$(type -t is_utility_installed)" ] && [ "$(type -t is_utility_installed)" = function ] && `is_utility_installed core tls-ca`; then
    sed -i "s#{{TLS_CERT}}#ssl_certificate /vagrant/certificates/${VVV_SITE_NAME}/dev.crt;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
    sed -i "s#{{TLS_KEY}}#ssl_certificate_key /vagrant/certificates/${VVV_SITE_NAME}/dev.key;#" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
else
    sed -i "s#{{TLS_CERT}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
    sed -i "s#{{TLS_KEY}}##" "${VVV_PATH_TO_SITE}/provision/vvv-nginx.conf"
fi
