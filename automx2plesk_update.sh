#!/bin/bash

# /opt/automx/automx2plesk_update.sh
#
# Script permettant de mettre à jour les fichier nginx et apache2 pour l'accès aux autoconfig.* et autodiscover.*
#
# crontab
# 5 * * * * /bin/bash /opt/automx/automx2plesk_update.sh >2 &>1

# mot de passe de la BDD plesk
PASSWORD=`cat /etc/psa/.psa.shadow`
NEWDOMAIN=0
# Liste des domaines ayant le mail
DOMAINS=`mysql --skip-column-names -uadmin -p$PASSWORD psa -e "SELECT name FROM domains AS dom LEFT JOIN DomainServices AS dos ON dom.id=dos.dom_id AND dos.type='mail' ORDER BY dom.name ASC; " | sort -u`;

# Boucle sur cette liste our créer les fichiers s'il n'existent pas
for DOMAIN in $DOMAINS;
do
  # fichiers nginx
  if [ ! -f "/etc/nginx/plesk.conf.d/automx/${DOMAIN}_automx.conf" ];
  then
    NEWDOMAIN=1
    cat > /etc/nginx/plesk.conf.d/automx/${DOMAIN}_automx.conf << EOF
#ATTENTION!
#
#DO NOT MODIFY THIS FILE BECAUSE IT WAS GENERATED AUTOMATICALLY,
#SO ALL YOUR CHANGES WILL BE LOST THE NEXT TIME THE FILE IS GENERATED.
server_name "autoconfig.$DOMAIN autdiscover.$DOMAIN"
EOF
  fi
  # fichiers apache2
  if [ ! -f "/etc/apache2/plesk.conf.d/automx/${DOMAIN}_automx.conf" ];
  then
    NEWDOMAIN=1
    cat > /etc/apache2/plesk.conf.d/automx/${DOMAIN}_automx.conf << EOF
#ATTENTION!
#
#DO NOT MODIFY THIS FILE BECAUSE IT WAS GENERATED AUTOMATICALLY,
#SO ALL YOUR CHANGES WILL BE LOST THE NEXT TIME THE FILE IS GENERATED.
ServerAlias "autoconfig.$DOMAIN autdiscover.$DOMAIN"
EOF
  fi
done

# on applique les modification si besoin
if [ $NEWDOMAIN ];
then
  service apache2 reload
  service nginx reload
fi
