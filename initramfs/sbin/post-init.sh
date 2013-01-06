#!/sbin/busybox sh

BB='/sbin/busybox'
$BB cp /data/user.log /data/user.log.bak
$BB rm /data/user.log
exec >>/data/user.log
exec 2>&1

# remount
$BB mount -t rootfs -o remount,rw rootfs

# start logfile output
echo "MIDNIGHT-I9100 POST-INIT BOOT LOG"
echo "$(date)"
# log basic system information
echo -n "Kernel: ";$BB uname -r
echo -n "PATH: ";echo $PATH
echo -n "ROM: ";cat /system/build.prop|$BB grep ro.build.display.id
echo -n "BusyBox:";$BB|$BB grep BusyBox

echo "$(date) modules"
ls -l /lib/modules

echo "$(date) modules loaded"
$BB lsmod

# print file contents <string messagetext><file output>
cat_msg_sysfile() {
    MSG=$1
    SYSFILE=$2
    echo -n "$(date) $MSG"
    cat $SYSFILE
}

# partitions
echo "$(date) mount"
for i in $($BB mount | $BB grep relatime | $BB cut -d " " -f3);do
    $BB mount -o remount,noatime $i
done
for i in $($BB mount | $BB grep ext4 | $BB cut -d " " -f3);do
    $BB mount -o remount,commit=20 $i
done

$BB mount

# read_ahead
echo "$(date) read_ahead"
echo 128 > /sys/block/mmcblk0/bdi/read_ahead_kb
echo 128 > /sys/block/mmcblk1/bdi/read_ahead_kb

# logger compiled into the kernel for now...
# insmod /lib/modules/logger.ko

# vm tweaks
echo "$(date) vm"
echo "0" > /proc/sys/vm/swappiness # Not really needed as no /swap used...
echo "1500" > /proc/sys/vm/dirty_writeback_centisecs # Flush after 20sec. (o:500)
echo "1500" > /proc/sys/vm/dirty_expire_centisecs # Pages expire after 20sec. (o:200)
echo "10" > /proc/sys/vm/dirty_background_ratio # flush pages later (default 5% active mem)
echo "20" > /proc/sys/vm/dirty_ratio # process writes pages later (default 20%)
echo "3" > /proc/sys/vm/page-cluster
echo "0" > /proc/sys/vm/laptop_mode
echo "0" > /proc/sys/vm/oom_kill_allocating_task
echo "0" > /proc/sys/vm/panic_on_oom
echo "1" > /proc/sys/vm/overcommit_memory
cat_msg_sysfile "swappiness: " /proc/sys/vm/swappiness
cat_msg_sysfile "dirty_writeback_centisecs: " /proc/sys/vm/dirty_writeback_centisecs
cat_msg_sysfile "dirty_expire_centisecs: " /proc/sys/vm/dirty_expire_centisecs
cat_msg_sysfile "dirty_background_ratio: " /proc/sys/vm/dirty_background_ratio
cat_msg_sysfile "dirty_ratio: " /proc/sys/vm/dirty_ratio
cat_msg_sysfile "page-cluster: " /proc/sys/vm/page-cluster
cat_msg_sysfile "laptop_mode: " /proc/sys/vm/laptop_mode
cat_msg_sysfile "oom_kill_allocating_task: " /proc/sys/vm/oom_kill_allocating_task
cat_msg_sysfile "panic_on_oom: " /proc/sys/vm/panic_on_oom
cat_msg_sysfile "overcommit_memory: " /proc/sys/vm/overcommit_memory

# security enhancements
# rp_filter must be reset to 0 if TUN module is used (issues)
echo "$(date) IPV4 sec"
echo 0 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 2 > /proc/sys/net/ipv6/conf/all/use_tempaddr
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo -n "$(date) SEC: ip_forward :";cat /proc/sys/net/ipv4/ip_forward
echo -n "$(date) SEC: rp_filter :";cat /proc/sys/net/ipv4/conf/all/rp_filter
echo -n "$(date) SEC: use_tempaddr :";cat /proc/sys/net/ipv6/conf/all/use_tempaddr
echo -n "$(date) SEC: accept_source_route :";cat /proc/sys/net/ipv4/conf/all/accept_source_route
echo -n "$(date) SEC: send_redirects :";cat /proc/sys/net/ipv4/conf/all/send_redirects
echo -n "$(date) SEC: icmp_echo_ignore_broadcasts :";cat /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# setprop tweaks
echo "$(date) prop"
setprop wifi.supplicant_scan_interval 180
echo -n "wifi.supplicant_scan_interval (is this actually used?): ";getprop wifi.supplicant_scan_interval

# kernel tweaks
echo "$(date) kernel"
echo 3750000 > /proc/sys/kernel/sched_latency_ns
echo 750000 > /proc/sys/kernel/sched_wakeup_granularity_ns
echo 750000 > /proc/sys/kernel/sched_min_granularity_ns
echo 0 > /proc/sys/kernel/panic_on_oops
echo 0 > /proc/sys/kernel/panic
cat_msg_sysfile "sched_latency_ns: " /proc/sys/kernel/sched_latency_ns
cat_msg_sysfile "sched_wakeup_granularity_ns: " /proc/sys/kernel/sched_wakeup_granularity_ns
cat_msg_sysfile "sched_min_granularity_ns: " /proc/sys/kernel/sched_min_granularity_ns
cat_msg_sysfile "panic_on_oops: " /proc/sys/kernel/panic_on_oops
cat_msg_sysfile "panic: " /proc/sys/kernel/panic

# IO scheduler tweaks
echo "$(date) IO"
for i in $($BB find /sys/block/mmc*);do
    if [ -d "$i/queue" ];then
        echo "$(date) adjusting $i" 
        echo "0" > $i/queue/rotational
        echo "0" > $i/queue/iostats
    fi	
done

# disable some debugging, by Speedmod/HC
echo "$(date) debugging"
echo "0" > /sys/module/wakelock/parameters/debug_mask
echo "0" > /sys/module/userwakelock/parameters/debug_mask
echo "0" > /sys/module/earlysuspend/parameters/debug_mask
echo "0" > /sys/module/alarm/parameters/debug_mask
echo "0" > /sys/module/alarm_dev/parameters/debug_mask
echo "0" > /sys/module/binder/parameters/debug_mask

# autoroot (skips if file .noautoroot found in /data/),
# adjusted from Speedmod/HC initramfs.
echo "$(date) autoroot"
if $BB [ -f /data/.noautoroot ];then
    echo "$(date)     file /data/.noautoroot found, skipping."
else
    if $BB [ -f /system/xbin/su ];then
	echo "$(date)     /system/xbin/su already exists, skipping"
    else
	echo "$(date)     copying su binary"
	$BB mount /system -o remount,rw
	$BB rm /system/bin/su
	$BB rm /system/xbin/su
	$BB cp /res/misc/su /system/xbin/su
	$BB chown 0.0 /system/xbin/su
	$BB chmod 6755 /system/xbin/su
	$BB mount /system -o remount,ro
    fi
    if $BB [ -f /system/app/Superuser.apk ];then
	echo "$(date)     /system/app/Superuser.apk already exists, skipping"
    else
	echo "$(date)     copying Superuser.apk"
	$BB mount /system -o remount,rw
	$BB rm /system/app/Superuser.apk
	$BB rm /data/app/Superuser.apk
	$BB cp /res/misc/Superuser.apk /system/app/Superuser.apk
	$BB chown 0.0 /system/app/Superuser.apk
	$BB chmod 644 /system/app/Superuser.apk
	$BB mount /system -o remount,ro
    fi
fi

sleep 12

echo "$(date) init.d"
if $BB [ -f /data/.noinitd ];then
    echo "$(date)     file /data/.noinitd found, skipping."
else
    if cd /system/etc/init.d >/dev/null 2>&1 ; then
        for file in S* ; do
            if ! ls "$file" >/dev/null 2>&1 ; then continue ; fi
            echo "$(date)     START '$file'"
            /system/bin/sh "$file"
            echo "$(date)     EXIT '$file' ($?)"
        done
    fi
fi
# the end
$BB mount -t rootfs -o remount,ro rootfs
exit 0

