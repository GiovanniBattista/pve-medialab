#!/usr/bin/env bash
# ----------------------------------------------------------------------------------
# Filename:     ahuabooks_config.sh
# Description:  Source script for configuring SW
# ----------------------------------------------------------------------------------

#---- Source -----------------------------------------------------------------------

DIR=$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )

#---- Dependencies -----------------------------------------------------------------

# Run Bash Header
source $DIR/basic_bash_utility.sh

# Install jq
if [[ ! $(dpkg -s jq 2>/dev/null) ]]
then
  apt-get install jq -y
fi

#---- Static Variables -------------------------------------------------------------

# Update these variables as required for your specific instance
app="$REPO_PKG_NAME"       # App name
app_uid="$APP_USERNAME"    # App UID
app_guid="$APP_GRPNAME"    # App GUID

#---- Other Variables --------------------------------------------------------------
#---- Other Files ------------------------------------------------------------------
#---- Body -------------------------------------------------------------------------

#---- Prerequisites

#---- Apply LazyLibrarian ES settings
# Stopping Lazylibrarian service

#pct_stop_systemctl "lazy.service"

# Setting Easy Script settings
#rm /home/media/lazylibrarian/.config/lazylibrarian.ini
#cp /tmp/lazylibrarian.ini /home/media/lazylibrarian/.config/lazylibrarian.ini

# Starting Lazylibrarian service 
#pct_start_systemctl "lazy.service"


#---- Apply Booksonic ES settings
# Stopping Booksonic service
echo "Stopping Booksonic service"
pct_stop_systemctl "booksonic.service"

# Setting Easy Script settings
echo "FastCacheEnabled=true" >> /home/media/booksonic/airsonic.properties
echo "IgnoreSymLinks=true" >> /home/media/booksonic/airsonic.properties
echo "WelcomeTitle=Welcome to Booksonic!" >> /home/media/booksonic/airsonic.properties
echo "WelcomeMessage2=" >> /home/media/booksonic/airsonic.properties

# Starting Booksonic service
echo "Starting Booksonic service"
pct_start_systemctl "booksonic.service"