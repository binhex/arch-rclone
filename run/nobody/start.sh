#!/bin/bash

rclone_log="/config/rclone/logs/rclone.log"

# create folder structure for config, temp and logs
mkdir -p /config/rclone/config /config/rclone/logs

# call log rotate script (background)
nohup /bin/bash -c "source /usr/local/bin/utils.sh && log_rotate --log-path '${rclone_log}' >> '/config/supervisord.log'" &

# split comma separated media shares
IFS=',' read -ra rclone_media_shares_list <<< "${RCLONE_MEDIA_SHARES}"

# if web ui enabled then supply config options to rclone
if [[ "${ENABLE_WEBUI}" == 'yes' ]]; then
	rclone_webui="--rc --rc-web-gui --rc-addr 0.0.0.0:8950 --rc-web-gui-no-open-browser --rc-user ${WEBUI_USER} --rc-pass ${WEBUI_PASS}"
else
	rclone_webui=""
fi

while true; do

	# loop over list of media share names
	for rclone_media_shares_item in "${rclone_media_shares_list[@]}"; do

		echo "[info] Running rclone for media share '${rclone_media_shares_item}', check rclone log file '${rclone_log}' for output..."
		if [[ "${DEBUG}" == 'yes' ]]; then
			echo "[debug] /usr/bin/rclone --config=${RCLONE_CONFIG_PATH} copy /media/${rclone_media_shares_item} ${RCLONE_REMOTE_NAME}:/${rclone_media_shares_item} ${rclone_webui} --log-file=${rclone_log} --log-level INFO"
		fi
		/usr/bin/rclone --config="${RCLONE_CONFIG_PATH}" copy "/media/${rclone_media_shares_item}" "${RCLONE_REMOTE_NAME}:/${rclone_media_shares_item}" ${rclone_webui} --log-file="${rclone_log}" --log-level INFO
		echo "[info] rclone for media share '${rclone_media_shares_item}' finished"

	done

	echo "[info] rclone finished, sleeping ${RCLONE_SLEEP_PERIOD} before re-running..."
	sleep "${RCLONE_SLEEP_PERIOD}"

done
