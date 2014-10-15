#
# Regular cron jobs for the cbhd package
#
0 4	* * *	root	[ -x /usr/bin/cbhd_maintenance ] && /usr/bin/cbhd_maintenance
