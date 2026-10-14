#!/bin/bash
# Report how many CPU cores a CLOSHA job can really use.
#
# Run it as a module on the portal twice, once with 4 cores and once with
# 1 core selected, and compare the reports. It reads nothing but the job's
# own environment and writes only to output_dir.
#
# Usage: bash core_check.sh output_dir="..."
for arg in "$@"; do
	case "$arg" in
		output_dir=*) output_dir="${arg#output_dir=}" ;;
	esac
done
output_dir="${output_dir:-.}"
mkdir -p "$output_dir"
report="${output_dir}/core_check.txt"

{
	echo "date                      : $(date '+%F %T')"
	echo "hostname                  : $(hostname)"
	echo "OMP_NUM_THREADS           : ${OMP_NUM_THREADS:-<unset>}"
	echo "nproc                     : $(nproc)"
	echo "nproc without OMP vars    : $(env -u OMP_NUM_THREADS -u OMP_THREAD_LIMIT nproc)"
	echo "nproc --all (whole node)  : $(nproc --all)"
	echo "affinity (taskset)        : $(taskset -cp $$ 2>/dev/null || echo n/a)"
	echo "Cpus_allowed_list         : $(awk '/Cpus_allowed_list/ {print $2}' /proc/self/status)"
	echo "cgroup v2 cpuset          : $(cat /sys/fs/cgroup/cpuset.cpus.effective 2>/dev/null || echo n/a)"
	echo "cgroup v2 cpu.max         : $(cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo n/a)"
	echo "cgroup v1 cfs quota/period: $(cat /sys/fs/cgroup/cpu/cpu.cfs_quota_us 2>/dev/null || echo n/a) / $(cat /sys/fs/cgroup/cpu/cpu.cfs_period_us 2>/dev/null || echo n/a)"
	echo "scheduler variables:"
	env | grep -iE '^(NSLOTS|NCPUS|NPROCS|PBS_N|PBS_NUM|SLURM_CPU|SLURM_JOB_CPUS|SLURM_NTASKS|LSB_DJOB_NUMPROC|JOB_|CLOSHA|BX_)' | sort | sed 's/^/  /'
	echo "end"
} | tee "$report"
