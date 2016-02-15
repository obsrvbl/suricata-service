#!/bin/sh
set -x

BINARY_PATH=/usr/bin/suricata
SURICATA_DIR=/opt/suricata

# Create a suricata system user and group with the given home directory
mkdir -p $SURICATA_DIR

useradd \
    --system \
    --user-group \
    --no-create-home \
    --home-dir $SURICATA_DIR \
    --shell /bin/false \
    suricata

# Create locations for rules, logs, and templates
mkdir -p $SURICATA_DIR/rules
mkdir -p $SURICATA_DIR/logs
cp /etc/suricata/*.config $SURICATA_DIR

# Set permissions
chown -R suricata:suricata $SURICATA_DIR
chown suricata:suricata $BINARY_PATH
chmod 0750 $BINARY_PATH
chmod 0754 $SURICATA_DIR/manage.sh
chmod g+w $SURICATA_DIR/logs
setcap cap_net_raw,cap_net_admin=eip $BINARY_PATH

# If the ona-service package (recommended) is installed, add the obsrvbl_ona
# user to the suricata group so it can read alert logs. Also allow it to
# update rules automatically.
if getent passwd | grep -q "^obsrvbl_ona:"; then
    usermod -a -G suricata obsrvbl_ona
    chown -R obsrvbl_ona $SURICATA_DIR/rules
fi

# Update library paths
ldconfig

# Install the Upstart service
# systemd (RHEL style)
if [ -d /usr/lib/systemd/system ] && [ -e /usr/bin/systemctl ]; then
    cp $SURICATA_DIR/system/suricata.service /usr/lib/systemd/system
    ln -s /usr/lib/systemd/system/suricata.service /etc/systemd/system/suricata.service
    /usr/bin/systemctl daemon-reload
    /usr/bin/systemctl start suricata.service
# systemd (Debian style)
elif [ -d /lib/systemd/system ] && [ -e /bin/systemctl ]; then
    cp $SURICATA_DIR/system/suricata.service /lib/systemd/system
    ln -s /lib/systemd/system/suricata.service /etc/systemd/system/suricata.service
    /bin/systemctl daemon-reload
    /bin/systemctl start suricata.service
# upstart
else
    cp $SURICATA_DIR/system/suricata.conf /etc/init/
    initctl reload-configuration
    initctl start suricata
fi
