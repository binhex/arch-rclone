#!/bin/bash

rclone_log="/config/rclone/logs/rclone.log"
rclone_webui_log="/config/rclone/logs/rclone_webui.log"

# create folder structure for config, temp and logs
mkdir -p /config/rclone/config /config/rclone/logs

# log rotate rclone log (background)
nohup /bin/bash -c "source /usr/local/bin/utils.sh && log_rotate --log-path '${rclone_log}' >> '/config/supervisord.log'" &

# split comma separated media shares
IFS=',' read -ra rclone_media_shares_list <<< "${RCLONE_MEDIA_SHARES}"

# if web ui enabled then run rclone web ui in rcd mode (listening to remote control commands only)
if [[ "${ENABLE_WEBUI}" == 'yes' ]]; then
	nohup /usr/bin/rclone rcd --config="${RCLONE_CONFIG_PATH}" --rc-web-gui --rc-addr 0.0.0.0:5572 --rc-web-gui-no-open-browser --rc-user=${WEBUI_USER} --rc-pass=${WEBUI_PASS} --transfers="${RCLONE_MAX_TRANSFERS}" --log-file="${rclone_webui_log}" --log-level INFO &

	echo "[info] Waiting for Rclone Web UI process to start listening on port 5572..."
	while [[ $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".5572\"") == "" ]]; do
		sleep 0.1
	done
	echo "[info] Rclone Web UI process listening on port 5572"

	# log rotate rclone web ui log (background)
	nohup /bin/bash -c "source /usr/local/bin/utils.sh && log_rotate --log-path '${rclone_webui_log}' >> '/config/supervisord.log'" &
fi

while true; do

	# loop over list of media share names
	for rclone_media_shares_item in "${rclone_media_shares_list[@]}"; do

		echo "[info] Running rclone for media share '${rclone_media_shares_item}', check rclone log file '${rclone_log}' for output..."
		# if web ui enabled then send rclone commands to web ui rcd, else run rclone cli
		if [[ "${ENABLE_WEBUI}" == 'yes' ]]; then
			# note timeout set to 0 to disable, waiting on rclone dev's to add in async
			# parameter as perm fix, but this is currently json only and requires all other
			# parameters to be re-defined as json also as you cannot mix parameters and json.
			# for ref json looks like this:- --json '{"_async": true}'
			/usr/bin/rclone rc "sync/${RCLONE_OPERATION}" srcFs="/media/${rclone_media_shares_item}" dstFs="${RCLONE_REMOTE_NAME}:/${rclone_media_shares_item}" --config="${RCLONE_CONFIG_PATH}" --transfers="${RCLONE_MAX_TRANSFERS}" --timeout=0 --rc-user=${WEBUI_USER} --rc-pass=${WEBUI_PASS} --log-file="${rclone_log}" --log-level INFO
		else
			/usr/bin/rclone "${RCLONE_OPERATION}" "/media/${rclone_media_shares_item}" "${RCLONE_REMOTE_NAME}:/${rclone_media_shares_item}" --config="${RCLONE_CONFIG_PATH}" --transfers="${RCLONE_MAX_TRANSFERS}" --log-file="${rclone_log}" --log-level INFO
		fi
		echo "[info] rclone for media share '${rclone_media_shares_item}' finished"

	done

	echo "[info] rclone finished, sleeping ${RCLONE_SLEEP_PERIOD} before re-running..."
	sleep "${RCLONE_SLEEP_PERIOD}"

done