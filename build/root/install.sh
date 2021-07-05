#!/bin/bash

# exit script if return code != 0
set -e

# build scripts
####

# download build scripts from github
curl --connect-timeout 5 --max-time 600 --retry 5 --retry-delay 0 --retry-max-time 60 -o /tmp/scripts-master.zip -L https://github.com/binhex/scripts/archive/master.zip

# unzip build scripts
unzip /tmp/scripts-master.zip -d /tmp

# move shell scripts to /root
mv /tmp/scripts-master/shell/arch/docker/*.sh /usr/local/bin/

# detect image arch
####

OS_ARCH=$(cat /etc/os-release | grep -P -o -m 1 "(?=^ID\=).*" | grep -P -o -m 1 "[a-z]+$")
if [[ ! -z "${OS_ARCH}" ]]; then
	if [[ "${OS_ARCH}" == "arch" ]]; then
		OS_ARCH="x86-64"
	else
		OS_ARCH="aarch64"
	fi
	echo "[info] OS_ARCH defined as '${OS_ARCH}'"
else
	echo "[warn] Unable to identify OS_ARCH, defaulting to 'x86-64'"
	OS_ARCH="x86-64"
fi

# pacman packages
####

# call pacman db and package updater script
source upd.sh

# define pacman packages
pacman_packages="rclone"

# install compiled packages using pacman
if [[ ! -z "${pacman_packages}" ]]; then
	pacman -S --needed $pacman_packages --noconfirm
fi

# aur packages
####

# define aur packages
aur_packages=""

# call aur install script (arch user repo)
source aur.sh

# container perms
####

# define comma separated list of paths
install_paths="/home/nobody"

# split comma separated string into list for install paths
IFS=',' read -ra install_paths_list <<< "${install_paths}"

# process install paths in the list
for i in "${install_paths_list[@]}"; do

	# confirm path(s) exist, if not then exit
	if [[ ! -d "${i}" ]]; then
		echo "[crit] Path '${i}' does not exist, exiting build process..." ; exit 1
	fi

done

# convert comma separated string of install paths to space separated, required for chmod/chown processing
install_paths=$(echo "${install_paths}" | tr ',' ' ')

# set permissions for container during build - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
chmod -R 775 ${install_paths}

# create file with contents of here doc, note EOF is NOT quoted to allow us to expand current variable 'install_paths'
# we use escaping to prevent variable expansion for PUID and PGID, as we want these expanded at runtime of init.sh
cat <<EOF > /tmp/permissions_heredoc

# get previous puid/pgid (if first run then will be empty string)
previous_puid=\$(cat "/root/puid" 2>/dev/null || true)
previous_pgid=\$(cat "/root/pgid" 2>/dev/null || true)

# if first run (no puid or pgid files in /tmp) or the PUID or PGID env vars are different
# from the previous run then re-apply chown with current PUID and PGID values.
if [[ ! -f "/root/puid" || ! -f "/root/pgid" || "\${previous_puid}" != "\${PUID}" || "\${previous_pgid}" != "\${PGID}" ]]; then

	# set permissions inside container - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
	chown -R "\${PUID}":"\${PGID}" ${install_paths}

fi

# write out current PUID and PGID to files in /root (used to compare on next run)
echo "\${PUID}" > /root/puid
echo "\${PGID}" > /root/pgid

EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /usr/local/bin/init.sh
rm /tmp/permissions_heredoc

# env vars
####

cat <<'EOF' > /tmp/envvars_heredoc

export RCLONE_CONFIG_PATH=$(echo "${RCLONE_CONFIG_PATH}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${RCLONE_CONFIG_PATH}" ]]; then
	echo "[info] RCLONE_CONFIG_PATH defined as '${RCLONE_CONFIG_PATH}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] RCLONE_CONFIG_PATH not defined,(via -e RCLONE_CONFIG_PATH), defaulting to '/config/rclone/config/rclone.conf'" | ts '%Y-%m-%d %H:%M:%.S'
	export RCLONE_CONFIG_PATH="/config/rclone/config/rclone.conf"
fi

if [ ! -f "${RCLONE_CONFIG_PATH}" ]; then
	echo "[crit] RCLONE_CONFIG_PATH '${RCLONE_CONFIG_PATH}' does not exist, exiting script..." | ts '%Y-%m-%d %H:%M:%.S'
	exit 1
fi

export RCLONE_MEDIA_SHARES=$(echo "${RCLONE_MEDIA_SHARES}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${RCLONE_MEDIA_SHARES}" ]]; then
	echo "[info] RCLONE_MEDIA_SHARES defined as '${RCLONE_MEDIA_SHARES}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[crit] RCLONE_MEDIA_SHARES not defined,(via -e RCLONE_MEDIA_SHARES), exiting script..." | ts '%Y-%m-%d %H:%M:%.S'
	exit 1
fi

export RCLONE_REMOTE_NAME=$(echo "${RCLONE_REMOTE_NAME}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${RCLONE_REMOTE_NAME}" ]]; then
	echo "[info] RCLONE_REMOTE_NAME defined as '${RCLONE_REMOTE_NAME}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[crit] RCLONE_REMOTE_NAME not defined,(via -e RCLONE_REMOTE_NAME), exiting script..." | ts '%Y-%m-%d %H:%M:%.S'
	exit 1
fi

export RCLONE_SLEEP_PERIOD=$(echo "${RCLONE_SLEEP_PERIOD}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${RCLONE_SLEEP_PERIOD}" ]]; then
	echo "[info] RCLONE_SLEEP_PERIOD defined as '${RCLONE_SLEEP_PERIOD}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] RCLONE_SLEEP_PERIOD not defined,(via -e RCLONE_SLEEP_PERIOD), defaulting to '24h'" | ts '%Y-%m-%d %H:%M:%.S'
	export RCLONE_SLEEP_PERIOD="24h"
fi

EOF

# replace env vars placeholder string with contents of file (here doc)
sed -i '/# ENVVARS_PLACEHOLDER/{
    s/# ENVVARS_PLACEHOLDER//g
    r /tmp/envvars_heredoc
}' /usr/local/bin/init.sh
rm /tmp/envvars_heredoc

# cleanup
cleanup.sh
