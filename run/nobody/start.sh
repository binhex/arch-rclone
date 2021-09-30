#!/bin/bash

function run_rclone(){

	# if web ui enabled then send rclone commands to web ui rcd, else run rclone cli
	if [[ "${ENABLE_WEBUI}" == 'yes' ]]; then

		# set flags for web gui
		rc_flag="rc"
		# note timeout set to 0 to disable, waiting on rclone dev's to add in async
		# parameter as perm fix, but this is currently json only and requires all other
		# parameters to be re-defined as json also as you cannot mix parameters and json.
		# for ref json looks like this:- --json '{"_async": true}'
		timeout_flag="--timeout=0"
		rc_auth_flag="--rc-user=${WEBUI_USER} --rc-pass=${WEBUI_PASS}"
		rclone_operation="sync/${RCLONE_OPERATION}"

	else

		# disable flags for web gui
		rc_flag=""
		timeout_flag=""
		rc_auth_flag=""
		rclone_operation="${RCLONE_OPERATION}"

	fi

	/usr/bin/rclone ${rc_flag} ${rclone_operation} ${sync_direction} --config="${RCLONE_CONFIG_PATH}" ${RCLONE_USER_FLAGS} ${timeout_flag} ${rc_auth_flag} --log-file="${rclone_log}" --log-level INFO
}

function run_rclone_webui() {

	# if web ui enabled then run rclone web ui in rcd mode (listening to remote control commands only)
	if [[ "${ENABLE_WEBUI}" == 'yes' ]]; then

		nohup /usr/bin/rclone rcd --config="${RCLONE_CONFIG_PATH}" --rc-web-gui --rc-addr 0.0.0.0:5572 --rc-web-gui-no-open-browser --rc-user=${WEBUI_USER} --rc-pass=${WEBUI_PASS} ${RCLONE_USER_FLAGS} --log-file="${rclone_webui_log}" --log-level INFO &

		echo "[info] Waiting for Rclone Web UI process to start listening on port 5572..."
		while [[ $(netstat -lnt | awk "\$6 == \"LISTEN\" && \$4 ~ \".5572\"") == "" ]]; do
			sleep 0.1
		done
		echo "[info] Rclone Web UI process listening on port 5572"

		# log rotate rclone web ui log (background)
		nohup /bin/bash -c "source /usr/local/bin/utils.sh && log_rotate --log-path '${rclone_webui_log}' >> '/config/supervisord.log'" &

	fi
}

function run_rclone_post_check(){

	mkdir -p '/config/rclone/reports' ; /usr/bin/rclone check ${post_check_sync_direction} --config="${RCLONE_CONFIG_PATH}" --one-way "--${RCLONE_POST_REPORT}" "/config/rclone/reports/${direction}-${rclone_remote_name_item}-${RCLONE_POST_REPORT}${rclone_media_shares_item_report_name,,}.txt" &> "/config/rclone/reports/${direction}-${rclone_remote_name_item}-${RCLONE_POST_REPORT}${rclone_media_shares_item_report_name,,}.txt"
}

function set_run_sync_flags(){

	if [[ "${RCLONE_DIRECTION}" == 'localtoremote' || "${RCLONE_DIRECTION}" == 'both' ]]; then

		if [[ "${ENABLE_WEBUI}" == 'yes' ]]; then

			sync_direction="srcFs=${rclone_media_shares_item} dstFs=${rclone_remote_name_item}:${rclone_media_shares_item}"

		else

			sync_direction="${rclone_media_shares_item} ${rclone_remote_name_item}:${rclone_media_shares_item}"

		fi

		echo "[info] Running rclone ${RCLONE_OPERATION} for local media share '${rclone_media_shares_item}' to remote '${rclone_remote_name_item}'..."
		run_rclone
		echo "[info] rclone ${RCLONE_OPERATION} finished"

	fi

	if [[ "${RCLONE_DIRECTION}" == 'remotetolocal' || "${RCLONE_DIRECTION}" == 'both' ]]; then

		if [[ "${ENABLE_WEBUI}" == 'yes' ]]; then

			sync_direction="srcFs=${rclone_remote_name_item}:${rclone_media_shares_item} dstFs=${rclone_media_shares_item}"

		else

			sync_direction="${rclone_remote_name_item}:${rclone_media_shares_item} ${rclone_media_shares_item}"

		fi

		echo "[info] Running rclone ${RCLONE_OPERATION} from remote '${rclone_remote_name_item}:${rclone_media_shares_item}' to local share '${rclone_media_shares_item}'..."
		run_rclone
		echo "[info] rclone ${RCLONE_OPERATION} finished"

	fi

}

function set_post_sync_flags(){

	if [[ "${RCLONE_POST_CHECK}" == 'yes' ]]; then

		# replace forward slashes with hyphens
		rclone_media_shares_item_report_name=${rclone_media_shares_item////-}

		if [[ "${RCLONE_DIRECTION}" == 'localtoremote' || "${RCLONE_DIRECTION}" == 'both' ]]; then

			direction="local-to-remote"
			post_check_sync_direction="${rclone_media_shares_item} ${rclone_remote_name_item}:${rclone_media_shares_item}"
			echo "[info] Running rclone post check, report located at '/config/rclone/reports/${direction}-${rclone_remote_name_item}-${RCLONE_POST_REPORT}${rclone_media_shares_item_report_name,,}.txt'..."
			run_rclone_post_check
			echo "[info] rclone post check finished"

		fi

		if [[ "${RCLONE_DIRECTION}" == 'remotetolocal' || "${RCLONE_DIRECTION}" == 'both' ]]; then

			direction="remote-to-local"
			post_check_sync_direction="${rclone_remote_name_item}:${rclone_media_shares_item} ${rclone_media_shares_item}"
			echo "[info] Running rclone post check, report located at '/config/rclone/reports/${direction}-${rclone_remote_name_item}-${RCLONE_POST_REPORT}${rclone_media_shares_item_report_name,,}.txt'..."
			run_rclone_post_check
			echo "[info] rclone post check finished"

		fi

	fi

}

function start() {

	rclone_log_path="/config/rclone/logs"

	# create folder structure for config, temp and logs
	mkdir -p "${rclone_log_path}"

	# define path to rclone log file
	rclone_log="${rclone_log_path}/rclone.log"

	# define path to webui log file
	rclone_webui_log="${rclone_log_path}/rclone_webui.log"

	# log rotate rclone log (background)
	nohup /bin/bash -c "source /usr/local/bin/utils.sh && log_rotate --log-path '${rclone_log}' >> '/config/supervisord.log'" &

	# log rotate rclone_webui log (background)
	nohup /bin/bash -c "source /usr/local/bin/utils.sh && log_rotate --log-path '${rclone_webui_log}' >> '/config/supervisord.log'" &

	# split comma separated media shares
	IFS=',' read -ra rclone_media_shares_list <<< "${RCLONE_MEDIA_SHARES}"

	# split comma separated remote name
	IFS=',' read -ra rclone_remote_name_list <<< "${RCLONE_REMOTE_NAME}"

	# if enabled run rclone web ui
	run_rclone_webui

	while true; do

		# loop over list of remote names
		for rclone_remote_name_item in "${rclone_remote_name_list[@]}"; do

			# loop over list of media share names
			for rclone_media_shares_item in "${rclone_media_shares_list[@]}"; do

				# strip out bucket name from media share (if present)
				rclone_media_shares_item_strip_bucket=$(echo "${rclone_media_shares_item}" | grep -P -o -m 1 '(\/[a-zA-Z0-9\s]+)+\/?$')

				if [[ ! -d "${rclone_media_shares_item_strip_bucket}" ]]; then
					echo "[warn] Media share '${rclone_media_shares_item_strip_bucket}' does not exist, skipping"
					continue
				fi

				# set sync flags and run rclone
				set_run_sync_flags

				# set post check flags and run post check
				set_post_sync_flags

			done

		done

		echo "[info] rclone finished, sleeping ${RCLONE_SLEEP_PERIOD} before re-running..."
		sleep "${RCLONE_SLEEP_PERIOD}"

	done
}

# kick off run
start