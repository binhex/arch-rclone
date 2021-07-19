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

# construct basedir from rclone config path
rclone_config_basedir=echo "$(dirname "${RCLONE_CONFIG_PATH}")"

# create path to store config and set permissions as we are doing this as root
mkdir -p "${rclone_config_basedir}"
chown -R "${PUID}:${PGID}" "${rclone_config_basedir}"

if [ ! -f "${RCLONE_CONFIG_PATH}" ]; then
	echo "[warn] RCLONE_CONFIG_PATH '${RCLONE_CONFIG_PATH}' does not exist, please run 'rclone config --config ${RCLONE_CONFIG_PATH}' from within the container" | ts '%Y-%m-%d %H:%M:%.S'
	sleep infinity
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

export RCLONE_OPERATION=$(echo "${RCLONE_OPERATION,,}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${RCLONE_OPERATION}" ]]; then
	echo "[info] RCLONE_OPERATION defined as '${RCLONE_OPERATION}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] RCLONE_OPERATION not defined,(via -e RCLONE_OPERATION), defaulting to 'copy'" | ts '%Y-%m-%d %H:%M:%.S'
	export RCLONE_OPERATION="copy"
fi

export RCLONE_POST_CHECK=$(echo "${RCLONE_POST_CHECK,,}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${RCLONE_POST_CHECK}" ]]; then
	echo "[info] RCLONE_POST_CHECK defined as '${RCLONE_POST_CHECK}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] RCLONE_POST_CHECK not defined,(via -e RCLONE_POST_CHECK), defaulting to 'yes'" | ts '%Y-%m-%d %H:%M:%.S'
	export RCLONE_POST_CHECK="yes"
fi

if [[ "${RCLONE_POST_CHECK}" == "yes" ]]; then
	export RCLONE_POST_REPORT=$(echo "${RCLONE_POST_REPORT,,}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${RCLONE_POST_REPORT}" ]]; then
		echo "[info] RCLONE_POST_REPORT defined as '${RCLONE_POST_REPORT}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[info] RCLONE_POST_REPORT not defined,(via -e RCLONE_POST_REPORT), defaulting to 'combined'" | ts '%Y-%m-%d %H:%M:%.S'
		export RCLONE_POST_REPORT="combined"
	fi
fi

export RCLONE_USER_FLAGS=$(echo "${RCLONE_USER_FLAGS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${RCLONE_USER_FLAGS}" ]]; then
	echo "[info] RCLONE_USER_FLAGS defined as '${RCLONE_USER_FLAGS}'" | ts '%Y-%m-%d %H:%M:%.S'
fi

export ENABLE_WEBUI=$(echo "${ENABLE_WEBUI}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${ENABLE_WEBUI}" ]]; then
	echo "[info] ENABLE_WEBUI defined as '${ENABLE_WEBUI}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[warn] ENABLE_WEBUI not defined (via -e ENABLE_WEBUI), defaulting to 'yes'" | ts '%Y-%m-%d %H:%M:%.S'
	export ENABLE_WEBUI="yes"
fi

if [[ "${ENABLE_WEBUI}" == "yes" ]]; then
	export WEBUI_USER=$(echo "${WEBUI_USER}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${WEBUI_USER}" ]]; then
		echo "[info] WEBUI_USER defined as '${WEBUI_USER}'" | ts '%Y-%m-%d %H:%M:%.S'
	else
		echo "[warn] WEBUI_USER not defined (via -e WEBUI_USER), defaulting to 'admin'" | ts '%Y-%m-%d %H:%M:%.S'
		export WEBUI_USER="admin"
	fi

	export WEBUI_PASS=$(echo "${WEBUI_PASS}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
	if [[ ! -z "${WEBUI_PASS}" ]]; then
		if [[ "${WEBUI_PASS}" == "rclone" ]]; then
			echo "[warn] WEBUI_PASS defined as '${WEBUI_PASS}' is weak, please consider using a stronger password" | ts '%Y-%m-%d %H:%M:%.S'
		else
			echo "[info] WEBUI_PASS defined as '${WEBUI_PASS}'" | ts '%Y-%m-%d %H:%M:%.S'
		fi
	else
		WEBUI_PASS_file="/config/rclone/security/WEBUI_PASS"
		if [ ! -f "${WEBUI_PASS_file}" ]; then
			# generate random password for web ui using SHA to hash the date,
			# run through base64, and then output the top 16 characters to a file.
			mkdir -p "/config/rclone/security" ; chown -R nobody:users "/config/rclone"
			date +%s | sha256sum | base64 | head -c 16 > "${WEBUI_PASS_file}"
		fi
		echo "[warn] WEBUI_PASS not defined (via -e WEBUI_PASS), using randomised password (password stored in '${WEBUI_PASS_file}')" | ts '%Y-%m-%d %H:%M:%.S'
		export WEBUI_PASS="$(cat ${WEBUI_PASS_file})"
	fi
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
