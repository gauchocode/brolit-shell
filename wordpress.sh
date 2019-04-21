#
# https://github.com/AbhishekGhosh/Ubuntu-16.04-Nginx-WordPress-Autoinstall-Bash-Script/
# https://alonganon.info/2018/11/17/make-a-super-fast-and-lightweight-wordpress-on-ubuntu-18-04-with-php-7-2-nginx-and-mariadb/
#
# TODO: habria que crear un usuario y pass de DB por sitio que se quiera instalar.

echo -n "Creating site on nginx..."

cd /var/www/
curl -O https://wordpress.org/latest.tar.gz
tar -xzxf latest.tar.gz
rm latest.tar.gz
mv wordpress $DOMAIN
#cd $domain
#cp wp-config-sample.php /var/www/${DOMAIN}/wp-config.php
rm /var/www/${DOMAIN}/wp-config-sample.php
chown -R www-data:www-data /var/www/${DOMAIN}
find /var/www/${DOMAIN} -type d -exec chmod g+s {} \;
chmod g+w /var/www/${DOMAIN}/wp-content
chmod -R g+w /var/www/${DOMAIN}/wp-content/themes
chmod -R g+w /var/www/${DOMAIN}/wp-content/plugins
echo "done."

#echo "Database to be used: localhost"
#echo "Database user: $1 (and also root)"
#echo "Database user password: $PASS for the user $1"
#sed -i "s/'DB_NAME', 'database_name_here'/'DB_NAME', '$1'/g" /var/www/$DOMAIN/wp-config.php;
#sed -i "s/'DB_USER', 'username_here'/'DB_USER', '$1'/g" /var/www/$DOMAIN/wp-config.php;
#sed -i "s/'DB_PASSWORD', 'password_here'/'DB_PASSWORD', '$PASS'/g" /var/www/$DOMAIN/wp-config.php;
#sed -i "s/'DB_HOST', 'localhost'/'DB_HOST', 'localhost'/g" /var/www/$DOMAIN/wp-config.php;
