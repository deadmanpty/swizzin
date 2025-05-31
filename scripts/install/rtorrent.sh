#!/bin/bash
# rTorrent installer
# Author: liara
# Copyright (C) 2017 Swizzin
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#
function _string() { perl -le 'print map {(a..z,A..Z,0..9)[rand 62] } 0..pop' 15; }

function _rconf() {
    cat > /home/${user}/.rtorrent.rc << EOF
# -- START HERE --
directory.default.set = /home/${user}/torrents/downloads
encoding.add = UTF-8
encryption = allow_incoming,try_outgoing,enable_retry
execute.nothrow = chmod,777,/home/${user}/.config/rpc.socket
execute.nothrow = chmod,777,/home/${user}/.sessions
network.scgi.open_local = /var/run/${user}/.rtorrent.sock
schedule2 = chmod_scgi_socket, 0, 0, "execute2=chmod,\"g+w,o=\",/var/run/${user}/.rtorrent.sock"
network.tos.set = throughput
schedule = watch_directory,5,5,load.start=/home/${user}/rwatch/*.torrent
session.path.set = /home/${user}/.sessions/
throttle.global_down.max_rate.set = 0
throttle.global_up.max_rate.set = 0
throttle.max_downloads.global.set = 500
throttle.max_uploads.global.set = 4000
throttle.max_peers.normal.set = 25
throttle.min_peers.normal.set = 10
throttle.max_peers.seed.set = 25
throttle.min_peers.seed.set = 10
throttle.max_downloads.set = 15
throttle.max_uploads.set = 25
network.port_range.set = 48660-52160
network.port_random.set = yes
dht.mode.set = disable
protocol.pex.set = no
trackers.use_udp.set = yes
trackers.delay_scrape.set = yes
network.max_open_files.set = 2048
network.max_open_sockets.set = 4096
network.http.max_open.set = 512
network.xmlrpc.size_limit.set = 24M
pieces.hash.on_completion.set = no
pieces.preload.type.set = 1
pieces.preload.min_rate.set = 50000
pieces.memory.max.set = 4500M
system.file.allocate.set = 2

method.set_key = event.download.inserted_new, "schedule2 = ((d.hash)), 0, 0, ((d.save_full_session))"

execute = {sh,-c,/usr/bin/php /srv/rutorrent/php/initplugins.php ${user} &}

# -- END HERE --
EOF
    chown ${user}:${user} -R /home/${user}/.rtorrent.rc
}

function _makedirs() {
    mkdir -p /home/${user}/torrents/downloads 2>> $log
    mkdir -p /home/${user}/.sessions
    mkdir -p /home/${user}/rwatch
    chown -R ${user}:${user} /home/${user}/{torrents,.sessions,rwatch} 2>> $log
    usermod -a -G www-data ${user} 2>> $log
    usermod -a -G ${user} www-data 2>> $log
}

_systemd() {
    cat > /etc/systemd/system/rtorrent@.service << EOF
[Unit]
Description=rTorrent
After=network.target

[Service]
Type=forking
KillMode=none
User=%i
ExecStartPre=-/bin/rm -f /home/%i/.sessions/rtorrent.lock
ExecStart=/usr/bin/screen -d -m -fa -S rtorrent /usr/bin/rtorrent
ExecStop=/usr/bin/screen -X -S rtorrent quit
WorkingDirectory=/home/%i/

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable -q --now rtorrent@${user} 2>> $log
}

export DEBIAN_FRONTEND=noninteractive

. /etc/swizzin/sources/functions/rtorrent
. /etc/swizzin/sources/functions/curl
noexec=$(grep "/tmp" /etc/fstab | grep noexec)
user=$(cut -d: -f1 < /root/.master.info)
rutorrent="/srv/rutorrent/"
port=$((RANDOM % 64025 + 1024))
portend=$((${port} + 1500))

if [[ -n $1 ]]; then
    user=$1
    _makedirs
    _rconf
    exit 0
fi

whiptail_rtorrent

if [[ -n $noexec ]]; then
    mount -o remount,exec /tmp
    noexec=1
fi
depends_rtorrent
if [[ ! $rtorrentver == repo ]]; then
    configure_curl
    echo_progress_start "Building c-ares from source"
    build_cares
    echo_progress_done
    echo_progress_start "Building curl from source"
    build_curl
    echo_progress_done
    configure_rtorrent
    #echo_progress_start "Building xmlrpc-c from source"
    #build_xmlrpc-c
    #echo_progress_done
    echo_progress_start "Building libtorrent from source"
    build_libtorrent_rakshasa
    echo_progress_done
    echo_progress_start "Building rtorrent from source"
    build_rtorrent
    echo_progress_done
else
    echo_info "Installing rtorrent with apt-get"
    rtorrent_apt
fi
echo_progress_start "Making ${user} directory structure"
_makedirs
echo_progress_done
echo_progress_start "setting up rtorrent.rc"
_rconf
_systemd
echo_progress_done

if [[ -n $noexec ]]; then
    mount -o remount,noexec /tmp
fi
echo_success "rTorrent installed"
touch /install/.rtorrent.lock
