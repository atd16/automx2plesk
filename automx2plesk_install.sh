#!/bin/bash

# /opt/automx/automx2plesk_intall.sh
#
# Script permettant d'installer et paramettre automx pour plesk
# et d'installer les fichiers de configuration nginx et apache2
# pour l'accès aux autoconfig.* et autodiscover.*
#

# Check for dependencies
function checkDependency() {
	if ! hash $1 2>&-;
	then
		echo -e "\e[0mInstallation de '$1'"
		apt -y install $1
                echo -e "\e[0mInstallation de $1 :  \e[32mOk"
	fi
}

if [ "$1" == "-h" ] ; then
    echo "Usage: `basename $0` [-h]"
    exit 0
fi

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
#
echo -e "\e[0mInstallation d'automx pour plesk"
echo -e "Mise à jour des dépôts et installation d'automx et ses dépendances"
#apt update && apt -y upgrade
echo -e "\e[0mMise à jour du systeme : \e[32mOk"
checkDependency "python-sqlalchemy"
checkDependency "python-m2crypto"
checkDependency "python-lxml"
checkDependency "automx"


# Configuration d'automx
PASSWORD=`cat /etc/psa/.psa.shadow`
cat > /etc/automx.conf <<EOF
# file: /etc/automx.conf

[automx]
provider = atd16.fr
domains = *

# debug = yes
# logfile = /var/log/automx/automx.log

# Protect against DoS
memcache = 127.0.0.1:11211
memcache_ttl = 600
client_error_limit = 20
rate_limit_exception_networks = 127.0.0.0/8, ::1/128

# The DEFAULT section is always merged into each other section. Each section
# can overwrite settings done here.
[DEFAULT]
account_type = email
account_name = Agence Technique Départementale de Charente
account_name_short = ATD16

# If a domain is listed in the automx section, it may have its own section. If
# none is found here, the global section is used.
[global]
backend = sql
action = settings
host = mysql://admin:$PASSWORD>@localhost/psa
query = SELECT CONCAT(m.mail_name,'@',d.name) AS 'mail_addr', d.name AS domain_name, u.contactName AS account_name FROM mail AS m LEFT JOIN domains AS d ON m.dom_id=d.id LEFT JOIN Subscriptions AS s ON d.id=s.object_id LEFT JOIN smb_users AS u ON u.id=m.userID WHERE s.object_type='domain' AND CONCAT(m.mail_name,'@',d.name)='%s' AND u.isLocked=0;
result_attrs = mail_addr, domain_name, account_name


account_name = \${account_name}
account_name_short =
# If you want to sign mobileconfig profiles, enable these options. Make sure
# that your webserver has proper privileges to read the key. The cert file
# must contain the server certificate and all intermediate certificates. You
# can simply CONCATenate these certificates.
#sign_mobileconfig = yes
#sign_cert = /path/to/cert
#sign_key = /path/to/key

smtp = yes
smtp_server = mail.\${domain_name}
smtp_port = 587
smtp_encryption = starttls
smtp_auth = plaintext
smtp_refresh_ttl = 6
smtp_default = yes
smtp_auth_identity = \${mail_addr}

imap = yes
imap_server = mail.\${domain_name}
imap_port = 143
imap_encryption = starttls
imap_auth = plaintext
imap_refresh_ttl = 6
imap_auth_identity = \${mail_addr}

pop = yes
pop_server = mail.\${domain_name}
pop_port = 110
pop_encryption = starttls
pop_auth = plaintext
pop_refresh_ttl = 6
pop_auth_identity = \${mail_addr}
EOF

if [ ! -f "/etc/nginx/plesk.conf.d/automx.conf" ];
then
  echo -e "\e[0mInstallation de /etc/nginx/plesk.conf.d/automx.conf"
  cat > /etc/nginx/plesk.conf.d/automx.conf <<EOF
#ATTENTION!
#
#DO NOT MODIFY THIS FILE BECAUSE IT WAS GENERATED AUTOMATICALLY,
#SO ALL YOUR CHANGES WILL BE LOST THE NEXT TIME THE FILE IS GENERATED.

server {
        listen 178.170.124.75:443 ssl;
        server_name autoconfig.* autodiscover.*;

        ssl_certificate             /opt/psa/var/certificates/cert-zlxb8w;
        ssl_certificate_key         /opt/psa/var/certificates/cert-zlxb8w;
        include "/etc/nginx/plesk.conf.d/automx/*.conf";

        client_max_body_size 128m;

        location / {
                proxy_pass https://178.170.124.75:7081;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
}

server {
        listen 178.170.124.75:80;
        server_name autoconfig.* autodiscover.*;
        include "/etc/nginx/plesk.conf.d/automx/*.conf";

        client_max_body_size 128m;

        location /.well-known/acme-challenge {
                root  /var/www/vhosts/default/htdocs;
        }
        location / {
                proxy_pass http://178.170.124.75:7080;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
                proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        }
}
EOF
fi
if [ ! -d "/etc/nginx/plesk.conf.d/automx" ];
then
  mkdir -p /etc/nginx/plesk.conf.d/automx
fi

if [ ! -f "/etc/nginx/plesk.conf.d/automx.conf" ];
then
  echo -e "\e[0mInstallation de /etc/apache2/plesk.conf.d/automx.conf"
  cat > /etc/apache2/plesk.conf.d/automx.conf <<EOF
#ATTENTION!
#
#DO NOT MODIFY THIS FILE BECAUSE IT WAS GENERATED AUTOMATICALLY,
#SO ALL YOUR CHANGES WILL BE LOST THE NEXT TIME THE FILE IS GENERATED.

<VirtualHost 178.170.124.75:7080 127.0.0.1:7080>
        ServerName autoconfig
        ServerAlias autoconfig.* autodiscover.*
        ServerAdmin serveurs_admin@atd16.fr

        IncludeOptional "/etc/apache2/plesk.conf.d/automx/*.conf"
        UseCanonicalName Off
        DocumentRoot "/usr/lib/automx"

        <IfModule mod_wsgi.c>
                WSGIScriptAlias /mail/config-v1.1.xml /usr/lib/automx/automx_wsgi.py
                <Directory "/usr/lib/automx">
                        Options -Indexes +FollowSymLinks
                        AllowOverride FileInfo
                        Require all granted
                </Directory>
        </IfModule>

</VirtualHost>

<IfModule mod_ssl.c>
        <VirtualHost 178.170.124.75:7081 127.0.0.1:7081>
                ServerName autodiscover
                ServerAlias autodiscover.*
                ServerAdmin serveurs_admin@atd16.fr

                IncludeOptional "/etc/apache2/plesk.conf.d/automx/*.conf"
                UseCanonicalName Off

                DocumentRoot "/usr/lib/automx"

                SSLEngine on
                SSLVerifyClient none
                SSLCertificateFile "/opt/psa/var/certificates/cert-zlxb8w"

                <IfModule mod_wsgi.c>
                        WSGIScriptAlias /Autodiscover/Autodiscover.xml /usr/lib/automx/automx_wsgi.py
                        WSGIScriptAlias /autodiscover/autodiscover.xml /usr/lib/automx/automx_wsgi.py
                        WSGIScriptAlias /mobileconfig /usr/lib/automx/automx_wsgi.py
                        <Directory "/usr/lib/automx">
                                Options -Indexes +FollowSymLinks
                                AllowOverride FileInfo
                                Require all granted
                        </Directory>
                </IfModule>

        </VirtualHost>
</IfModule>
EOF
fi
if [ ! -d "/etc/apache2/plesk.conf.d/automx" ];
then
  mkdir -p /etc/apache2/plesk.conf.d/automx
fi

/bin/bash /opt/automx/automx2plesk_update.sh
