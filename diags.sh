#!/bin/sh
out="cpu-throttle-$(hostname)-$(date +%Y%m%d-%H%M%S).log"
{
echo "uptime"
uptime
echo "grep MHz /proc/cpuinfo (lowest, highest)"
grep MHz /proc/cpuinfo | sort -t: -k2 -n | sed -n '1p;$p'
echo "cpufreq: scaling_driver scaling_governor scaling_max_freq cpuinfo_max_freq"
grep . /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq
echo "boost, amd_pstate_max_freq, energy_performance_preference"
grep . /sys/devices/system/cpu/cpufreq/boost /sys/devices/system/cpu/cpu0/cpufreq/amd_pstate_max_freq /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference
echo "cat /sys/devices/system/cpu/amd_pstate/status"
cat /sys/devices/system/cpu/amd_pstate/status
echo "cat /sys/devices/system/cpu/intel_pstate/status max_perf_pct no_turbo"
grep . /sys/devices/system/cpu/intel_pstate/status /sys/devices/system/cpu/intel_pstate/max_perf_pct /sys/devices/system/cpu/intel_pstate/no_turbo
echo "powerprofilesctl get"
powerprofilesctl get
echo "cat /sys/firmware/acpi/platform_profile"
cat /sys/firmware/acpi/platform_profile
echo "grep . /sys/class/power_supply/*/online"
grep . /sys/class/power_supply/*/online
echo "journalctl -k -b | grep -iE 'throttl|prochot|pstate|thermal'"
journalctl -k -b | grep -iE 'throttl|prochot|pstate|thermal'
} 2>&1 | tee "$out"
echo "saved to $out"
