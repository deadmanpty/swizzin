#! /bin/bash
# Webmin yeeter
# flying_sausages 2020 for swizzin

apt autoremove --purge webmin -y
rm -rf /etc/webmin
rm -rf /etc/apt/sources.list.d/webmin-stable.list

#if [[ -f /install/.nginx.lock ]]; then
#    rm /etc/nginx/apps/webmin.conf
#    systemctl reload nginx
#fi

# rm -rf /install/.webmin.lock
