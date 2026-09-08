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
## Instance layout (base paths)
method.insert = cfg.basedir,  private|const|string, (cat,"/home/${user}/")
method.insert = cfg.download, private|const|string, (cat,(cfg.basedir),"/home/${user}/torrents/downloads/")
method.insert = cfg.logs,     private|const|string, (cat,(cfg.basedir),"/home/${user}/rlog/")
method.insert = cfg.logfile,  private|const|string, (cat,(cfg.logs),"rtorrent-",(system.time),".log")
method.insert = cfg.session,  private|const|string, (cat,(cfg.basedir),"/home/${user}/.sessions/")
method.insert = cfg.watch,    private|const|string, (cat,(cfg.basedir),"/home/${user}/rwatch/")
method.insert = socket.path,  private|const|string, (cat,"/var/run/${user}/")

execute.nothrow = chmod,777,/home/${user}/.config/rpc.socket

## Create instance directories
execute.throw = sh, -c, (cat,\
    "mkdir -p \"",(cfg.download),"\" ",\
    "\"",(cfg.logs),"\" ",\
    "\"",(cfg.session),"\" ",\
    "\"",(cfg.watch),"/load\" ",\
    "\"",(cfg.watch),"/start\" ")

## Listening port for incoming peer traffic (fixed; you can also randomize it)
network.listen.port.range.set = 48160-50160
network.listen.port.random.set = yes

## Tracker-less torrent and UDP tracker support
## (conservative settings for 'private' trackers, change for 'public')
dht.mode.set = disable
protocol.pex.set = no

## Peer settings
throttle.global_down.max_rate.set = 0
throttle.global_up.max_rate.set = 0
throttle.max_downloads.global.set = 150
throttle.max_uploads.global.set = 300
throttle.max_downloads.set = 25
throttle.max_uploads.set = 50
throttle.max_peers.normal.set = 50
throttle.min_peers.normal.set = 1
throttle.max_peers.seed.set = -1
throttle.min_peers.seed.set = -1
#trackers.numwant.set = 80
trackers.delay_scrape = yes

# Select encryption for handshake and connection:
#
# protocol.encryption.set = {deny,allow,prefer,require}
# protocol.encryption.set = handshake_{deny,allow,prefer,require}, stream_{deny,allow,prefer,require}
#
#protocol.encryption.set = deny
#protocol.encryption.set = require
#protocol.encryption.set = handshake_prefer, stream_deny
#protocol.encryption.set = handshake_require, stream_prefer

## Limits for file handle resources, this is optimized for
## an `ulimit` of 1024 (a common default). You MUST leave
## a ceiling of handles reserved for rTorrent's internal needs!

# Deprecated, see: https://github.com/rakshasa/rtorrent/wiki/Socket-Manager-and-Resource-Allocation

## Memory resource usage (increase if you have a large number of items loaded,
## and/or the available resources to spend)
pieces.preload.type.set = 1
pieces.preload.min_rate.set = 50000
pieces.memory.max.set = 5200M
system.file.allocate.set = 2
network.xmlrpc.size_limit.set = 32M

## Basic operational settings (no need to change these)
session.path.set = (cat, (cfg.session))
directory.default.set = (cat, (cfg.download))
log.execute = (cat, (cfg.logs), "execute.log")
#log.xmlrpc = (cat, (cfg.logs), "xmlrpc.log")
execute.nothrow = sh, -c, (cat, "echo >",\
    (socket.path), "rtorrent.pid", " ",(system.pid))

## Other operational settings (check & adapt)
system.umask.set = 0007
session.use_lock.set = no
system.cwd.set = (directory.default)
network.http.dns_cache_timeout.set = 25
schedule = monitor_diskspace, 15, 60, ((close_low_diskspace, 1000M))
#pieces.hash.on_completion.set = no
#view.sort_current = seeding, greater=d.ratio=
#keys.layout.set = qwerty
#network.http.capath.set = "/etc/ssl/certs"
#network.http.ssl_verify_peer.set = 0
#network.http.ssl_verify_host.set = 0
#network.rpc.use_xmlrpc.set = true
#network.rpc.use_jsonrpc.set = true


## Some additional values and commands
method.insert = system.startup_time, value|const, (system.time)
method.insert = d.data_path, simple,\
    "if=(d.is_multi_file),\
        (cat, (d.directory), /),\
        (cat, (d.directory), /, (d.name))"
method.insert = d.session_file, simple, "cat=(session.path), (d.hash), .torrent"

## Watch directories (add more as you like, but use unique schedule names)
## Add torrent
schedule = watch_load, 11, 10, ((load.verbose, (cat, (cfg.watch), "load/*.torrent")))
## Add & download straight away
schedule = watch_start, 10, 10, ((load.start_verbose, (cat, (cfg.watch), "start/*.torrent")))

## Run the rTorrent process as a daemon in the background
## (and control via XMLRPC sockets)
system.daemon.set = true
network.scgi.open_local = (cat,(socket.path),rpc.socket)

## Logging:
##   Levels = critical error warn notice info debug
##   Groups = connection_* dht_* peer_* rpc_* storage_* thread_* tracker_* torrent_*
print = (cat, "Logging to ", (cfg.logfile))
log.open_file = "log", (cfg.logfile)
log.add_output = "info", "log"
#log.add_output = "tracker_debug", "log"

### END of rtorrent.rc ###

# -- END HERE --
EOF
    chown ${user}:${user} -R /home/${user}/.rtorrent.rc
}

function _makedirs() {
    mkdir -p /home/${user}/torrents/downloads 2>> $log
    mkdir -p /home/${user}/.sessions
    mkdir -p /home/${user}/rlog
    mkdir -p /home/${user}/rwatch
    chown -R ${user}:${user} /home/${user}/{torrents,.sessions,rlog,rwatch} 2>> $log
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
ExecStartPre=-/bin/rm -f /home/%i/.session/rtorrent.lock
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
