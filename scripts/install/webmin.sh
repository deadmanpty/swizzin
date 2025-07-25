#! /bin/bash
# shellcheck disable=SC2024
# Webmin installer
# flying_sausages for swizzin 2020

_install_webmin() {
    echo_progress_start "Installing Webmin repo"
    curl -o webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh 2>> "${log}"
    bash webmin-setup-repo.sh 2>> "${log}"
    echo_progress_done "Repo added"
    apt_update
    apt install webmin --install-recommends -y
}

_install_webmin
# if [[ -f /install/.nginx.lock ]]; then
#    echo_progress_start "Configuring nginx"
#    bash /etc/swizzin/scripts/nginx/webmin.sh
#    systemctl reload nginx
#    echo_progress_done
# else
    echo_info "Webmin will run on port 10000"
# fi

echo_success "Webmin installed"
echo_info "Please use any account with sudo permissions to log in"

touch /install/.webmin.lock
