#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     deluge_sw.sh
# Description:  Source script for CT SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $DIR/basic_bash_utility.sh

#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="${REPO_PKG_NAME,,}"    # App name
app_uid="$APP_USERNAME"     # App UID
app_guid="$APP_GRPNAME"     # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites
#---- Prerequisites
echo "Creating Application settings, logs folder..."
mkdir -p /home/media/lazylibrarian/{Logs,.config}
mkdir -p /home/media/calibre/{logs,.config}
mkdir -p /home/media/calibre-web/{logs,.config}
mkdir -p /home/media/booksonic/transcode
mkdir -p /home/media/podgrab
chown -hR 1605:65605 /home/media

echo "Creating storage folders..."
su - $app_uid -c 'mkdir -p /mnt/books/{ebooks,comics,magazines}'
su - $app_uid -c 'mkdir -p /mnt/audio/{audiobooks,podcasts}'
su - $app_uid -c 'mkdir -p /mnt/public/autoadd/direct_import/lazylibrarian'

echo "Installing prerequisites (be patient, might take a while)..."
apt-get install git xdg-utils xvfb python3-pip python3-venv libnss3 python3-openssl python3-oauthlib libffi-dev imagemagick rename id3v2 id3tool unzip ffmpeg libgl1-mesa-glx unrar libegl1 libopengl0 libgl1-mesa-glx libxcb-cursor0 -y
pip install --no-warn-script-location apprise urllib3 Pillow python-Levenshtein

# Prerequisite - Installing Go for Podgrab
GO_URL="$(curl -s https://go.dev/dl/ | grep -oP 'go[0-9]+\.[0-9]+(\.[0-9]+)?\.linux-amd64\.tar\.gz' | sort -V | uniq | tail -n 1)"
wget https://go.dev/dl/${GO_URL} -P /tmp
rm -rf /usr/local/go
tar -C /usr/local -xzf /tmp/${GO_URL}
rm /tmp/${GO_URL}
echo "export PATH=$PATH:/usr/local/go/bin" >> /etc/profile
source /etc/profile
echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bashrc
if ! go version > /dev/null ; then
  echo -e "Go installation status: \033[0;31mFail\033[0m\n\nCannot proceed without Go software - problem unknown.\nUser intervention required. Exiting installation script in 3 second..."
  sleep 3
  exit 0
fi

#---- Installing Lazylibrarian
echo "Installing LazyLibrarian software (be patient, might take a while)..."
git clone https://gitlab.com/LazyLibrarian/LazyLibrarian.git /opt/LazyLibrarian
chown -R 1605:65605 /opt/LazyLibrarian
mkdir -p /home/media/lazylibrarian/.config
chown -R 1605:65605 /home/media/lazylibrarian/.config
git config --global --add safe.directory /opt/LazyLibrarian
cp /tmp/lazylibrarian.ini /home/media/lazylibrarian/.config/

echo "Installing required dependencies for LazyLibrarian"
cd /opt/LazyLibrarian
python3 -m venv venv
./venv/bin/python3 -m pip install -r requirements.txt

echo "Creating LazyLibrarian system.d file..."
cat <<EOF | tee /etc/systemd/system/lazy.service > /dev/null
[Unit]
Description=Lazylibrarian

[Service]
ExecStart=/opt/LazyLibrarian/venv/bin/python3 /opt/LazyLibrarian/LazyLibrarian.py --daemon --config /home/media/lazylibrarian/.config/lazylibrarian.ini --datadir /home/media/lazylibrarian --nolaunch --quiet
GuessMainPID=no
Type=forking
User=media
Group=medialab
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF


#---- Installing Calibre
echo "Installing Calibre software (be patient, might take a while)..."
set +Eeuo pipefail
wget -nv -O- https://download.calibre-ebook.com/linux-installer.sh | sh /dev/stdin > /dev/null
set -Eeuo pipefail
chown -hR 1605:65605 /opt/calibre

echo "Creating the Calibre database (by adding a dummy book)...."
su - $app_uid -c 'cp /tmp/hard_times.epub /mnt/public/autoadd/direct_import/lazylibrarian/hard_times.epub'
su - $app_uid -c 'xvfb-run calibredb add /mnt/public/autoadd/direct_import/lazylibrarian/hard_times.epub --library-path /mnt/books/ebooks'
su - $app_uid -c 'rm /mnt/public/autoadd/direct_import/lazylibrarian/hard_times.epub'

echo "Creating a Calibre log file...."
touch /home/media/calibre/logs/calibre.log
chown -hR 1605:65605 /home/media/calibre/logs/calibre.log

echo "Creating Calibre-server system.d file..."
cat <<'EOF' | tee /etc/systemd/system/calibre-server.service > /dev/null
[Unit]
Description=calibre content server
After=network.target calibre-web.service
[Service]
Type=simple
User=media
Group=medialab
ExecStart="/usr/bin/calibre-server" "/mnt/books/ebooks/" --enable-local-write --listen-on=:: --log="/home/media/calibre/logs/calibre.log" --max-log-size 2
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

#---- Installing Calibre-web
echo "Installing Calibre-web software (be patient, might take a while)..."
wget https://github.com/janeczku/calibre-web/archive/master.zip -O /tmp/master.zip
unzip -q /tmp/master.zip -d /tmp
mv /tmp/calibre-web-master /opt/calibre-web
chown -hR 1605:65605 /opt/calibre-web
cd /opt/calibre-web 
python3 -m venv venv
./venv/bin/python3 -m pip install -r requirements.txt

echo "Creating Calibre-web system.d file..."
cat <<'EOF' | tee /etc/systemd/system/calibre-web.service > /dev/null
[Unit]
Description=Calibre-Web
After=network.target

[Service]
Type=simple
User=media
Group=medialab
ExecStart=/opt/calibre-web/venv/bin/python3 /opt/calibre-web/cps.py
WorkingDirectory=/home/media/calibre-web/

[Install]
WantedBy=multi-user.target
EOF

#---- Installing Booksonic
echo "Installing Booksonic software (be patient, might take a while)..."
apt-get install openjdk-8-jre -y
mkdir -p /opt/booksonic
wget https://github.com/popeen/Booksonic-Air/releases/download/v2009.1.0/booksonic.war -P /opt/booksonic
chown -hR 1605:65605 /opt/booksonic

echo "Creating Booksonic system.d file..."
cat <<'EOF' | tee /etc/systemd/system/booksonic.service > /dev/null
[Unit]
Description=Booksonic Media Server
After=remote-fs.target network.target
AssertPathExists=/home/media/booksonic

[Service]
Type=simple
Environment="JAVA_JAR=/opt/booksonic/booksonic.war"
Environment="JAVA_OPTS=-Xmx512m"
Environment="BOOKSONIC_HOME=/home/media/booksonic"
Environment="PORT=4040"
Environment="CONTEXT_PATH=/booksonic"
Environment="JAVA_ARGS="
EnvironmentFile=-/etc/default/booksonic
ExecStart=/usr/bin/java \
          $JAVA_OPTS \
          -Dairsonic.home=${BOOKSONIC_HOME} \
          -Dairsonic.defaultMusicFolder=/mnt/audio/audiobooks \
          -Dairsonic.defaultPodcastFolder=/mnt/audio/podcasts \
          -Dairsonic.defaultPlaylistFolder=/home/media/booksonic/playlists \
          -Dserver.servlet.contextPath=${CONTEXT_PATH} \
          -Dserver.port=${PORT} \
          -jar ${JAVA_JAR} $JAVA_ARGS
User=media
#Group=medialab

DevicePolicy=closed
DeviceAllow=char-alsa rw
NoNewPrivileges=yes
PrivateTmp=yes
PrivateUsers=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
RestrictNamespaces=yes
RestrictRealtime=yes
SystemCallFilter=~@clock @debug @module @mount @obsolete @privileged @reboot @setuid @swap
ReadWritePaths=/home/media/booksonic

# You can uncomment the following line if you're not using the jukebox
# This will prevent airsonic from accessing any real (physical) devices
#PrivateDevices=yes

# You can change the following line to `strict` instead of `full`
# if you don't want airsonic to be able to
# write anything on your filesystem outside of AIRSONIC_HOME.
ProtectSystem=full

# You can uncomment the following line if you don't have any media
# in /home/…. This will prevent airsonic from ever reading/writing anything there.
#ProtectHome=true

# You can uncomment the following line if you're not using the OpenJDK.
# This will prevent processes from having a memory zone that is both writeable
# and executable, making hacker's lives a bit harder.
#MemoryDenyWriteExecute=yes

[Install]
WantedBy=multi-user.target
EOF

# Create directory symlink to ffmpeg
ln -s /usr/bin/ffmpeg /home/media/booksonic/transcode
chown -h media:medialab /home/media/booksonic/transcode/ffmpeg


#---- Installing Podgrab
echo "Installing Podgrab software (be patient, might take a while)..."
apt-get install -y git ca-certificates ufw gcc > /dev/null
git clone --depth 1 https://github.com/akhilrex/podgrab /tmp/podgrab
bash -c 'cd /tmp/podgrab && /usr/local/go/bin/go mod tidy'
mkdir -p /tmp/podgrab/dist
bash -c 'cp -r /tmp/podgrab/client /tmp/podgrab/dist'
bash -c 'cp -r /tmp/podgrab/webassets /tmp/podgrab/dist'
bash -c 'cp /tmp/podgrab/.env /tmp/podgrab/dist'
bash -c 'cd /tmp/podgrab && /usr/local/go/bin/go build -o ./dist/podgrab ./main.go'
mkdir -p /usr/local/bin/podgrab
bash -c 'mv -v /tmp/podgrab/dist/* /usr/local/bin/podgrab &> /dev/null'
bash -c 'mv -v /tmp/podgrab/dist/.env /usr/local/bin/podgrab'
rm -R /tmp/podgrab


# Set environment file
cat <<'EOF' | tee /usr/local/bin/podgrab/.env > /dev/null
CONFIG=/home/media/podgrab
DATA=/mnt/audio/podcasts
CHECK_FREQUENCY = 360
PASSWORD=
PORT = 4041
# test
EOF

echo "Creating Podgrab system.d file..."
cat <<'EOF' | tee /etc/systemd/system/podgrab.service > /dev/null
[Unit]
Description=Podgrab
After=remote-fs.target network.target

[Service]
ExecStart=/usr/local/bin/podgrab/podgrab
WorkingDirectory=/usr/local/bin/podgrab/
User=media
Group=medialab

[Install]
WantedBy=multi-user.target
EOF

#---- Installing default Calibre plugins
echo "Installing Calibre plugins..."
wget --content-disposition $( curl -s https://api.github.com/repos/apprenticeharper/DeDRM_tools/releases/latest | grep "browser_download_url.*zip" | cut -d : -f 2,3 | tr -d \" ) -P /tmp/
unzip -q /tmp/$( curl -s https://api.github.com/repos/apprenticeharper/DeDRM_tools/releases/latest | grep "browser_download_url.*zip" | cut -d : -f 2,3 | tr -d \" | sed 's/.*\///' ) -d /tmp
calibre-customize --add /tmp/DeDRM_plugin.zip
calibre-customize --enable DeDRM_plugin



# Start the App
systemctl -q daemon-reload
systemctl enable --now -q lazy.service
systemctl enable --now -q calibre-server.service
systemctl enable --now -q calibre-web.service
systemctl enable --now -q booksonic.service
systemctl enable --now -q podgrab.service


#---- Create App backup folder on NAS
if [ -d "/mnt/backup" ]
then
 su - $app_uid -c "mkdir -p /mnt/backup/$REPO_PKG_NAME"
fi
#-----------------------------------------------------------------------------------