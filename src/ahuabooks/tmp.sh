pct push 115 /mnt/pve/nas-01-git/ahuacate/pve-medialab/src/ahuabooks/config/charles-dickens_hard-times.epub /tmp/hard_times.epub
pct push 115 /mnt/pve/nas-01-git/ahuacate/pve-medialab/src/ahuabooks/config/default_lazylibrarian.ini /tmp/lazylibrarian.ini --group 65605 --user 1605
pct push 115 /mnt/pve/nas-01-git/ahuacate/pve-medialab/common/bash/src/basic_bash_utility.sh /tmp/basic_bash_utility.sh -perms 755
pct push 115 /mnt/pve/nas-01-git/ahuacate/pve-medialab/src/ahuabooks/ahuabooks_sw.sh /tmp/ahuabooks_sw.sh -perms 755
pct exec 115 -- bash -c "export REPO_PKG_NAME=ahuabooks APP_USERNAME=media APP_GRPNAME=medialab && /tmp/ahuabooks_sw.sh"

pct push 115 /mnt/pve/nas-01-git/ahuacate/pve-medialab/src/ahuabooks/config/ahuabooks_config.sh /tmp/ahuabooks_config.sh -perms 755
pct exec 115 -- bash -c "export REPO_PKG_NAME=ahuabooks APP_USERNAME=media APP_GRPNAME=medialab && /tmp/ahuabooks_config.sh"


Unable to read current version from version.txt: [Errno 2] No such file or directory: '/home/media/lazylibrarian/cache/version.txt'


/opt/LazyLibrarian/venv/bin/python3 /opt/LazyLibrarian/LazyLibrarian.py --config /home/media/lazylibrarian/.config/lazylibrarian.ini --datadir /home/media/lazylibrarian --nolaunch --quiet --update