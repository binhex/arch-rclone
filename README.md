**Application**

[Rclone](https://rclone.org/)

**Description**

Rclone is a command line program to manage files on cloud storage. It is a feature rich alternative to cloud vendors' web storage interfaces. Over 40 cloud storage products support rclone including S3 object stores, business & consumer file storage services, as well as standard transfer protocols.

Rclone has powerful cloud equivalents to the unix commands rsync, cp, mv, mount, ls, ncdu, tree, rm, and cat. Rclone's familiar syntax includes shell pipeline support, and --dry-run protection. It is used at the command line, in scripts or via its API.

Users call rclone "The Swiss army knife of cloud storage", and "Technology indistinguishable from magic".

**Build notes**

Latest stable Radarr release from Arch Repository.

**Usage**
```
docker run -d \
    -p 53682:53682 \
    -p 5572:5572 \
    --name=<container name> \
    -v <path for media files>:/media \
    -v <path for config files>:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e RCLONE_CONFIG_PATH=<path to rclone config file> \
    -e RCLONE_MEDIA_SHARES=<media share names to copy|sync> \
    -e RCLONE_REMOTE_NAME=<rclone remote name in config file> \
    -e RCLONE_SLEEP_PERIOD=<period to sleep between rclone copy|sync> \
    -e ENABLE_WEBUI=yes|no \
    -e WEBUI_USER=<rclone web ui username> \
    -e WEBUI_PASS=<rclone web ui password> \
    -e UMASK=<umask for created files> \
    -e PUID=<uid for user> \
    -e PGID=<gid for user> \
    binhex/arch-rclone
```

Please replace all user variables in the above command defined by <> with the correct values.

**Access application**

Requires `-e ENABLE_WEBUI=yes`

`http://<host ip>:5572`

**Example**
```
docker run -d \
    -p 53682:53682 \
    -p 5572:5572 \
    --name=binhex-rclone \
    -v /media/movies:/media \
    -v /apps/docker/radarr:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e RCLONE_CONFIG_PATH=/config/rclone/config/rclone.conf \
    -e RCLONE_MEDIA_SHARES=Music,Pictures,Videos \
    -e RCLONE_REMOTE_NAME=onedrive-business-encrypt \
    -e RCLONE_SLEEP_PERIOD=24h \
    -e ENABLE_WEBUI=yes \
    -e WEBUI_USER=admin \
    -e WEBUI_PASS=rclone \
    -e UMASK=000 \
    -e PUID=0 \
    -e PGID=0 \
    binhex/arch-rclone
```

**Notes**

User ID (PUID) and Group ID (PGID) can be found by issuing the following command for the user you want to run the container as:-

```
id <username>
```
___
If you appreciate my work, then please consider buying me a beer  :D

[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MM5E27UX6AUU4)

[Documentation](https://github.com/binhex/documentation) | [Support forum](http://lime-technology.com/forum/index.php?topic=55549.0)