for_chunkservers() {
	operation=${1}
	shift
	for csid in "${@}"; do
		saunafs_chunkserver_daemon $csid "${operation}" &
	done
	wait
	if [[ $operation == stop ]]; then
		nr_of_running_chunkservers=$((nr_of_running_chunkservers - $#))
	elif [[ $operation == start ]]; then
		nr_of_running_chunkservers=$((nr_of_running_chunkservers + $#))
	else
		test_fail "Wrong branch"
	fi
	saunafs_wait_for_ready_chunkservers $nr_of_running_chunkservers
}

timeout_set "1 minute"
CHUNKSERVERS=15 \
	MASTER_EXTRA_CONFIG="CHUNKS_LOOP_MIN_TIME = 1`
			`|CHUNKS_LOOP_MAX_CPU = 90`
			`|REPLICATIONS_DELAY_INIT = 0`
			`|ACCEPTABLE_DIFFERENCE = 10.0`
			`|DISABLE_CHUNKS_DEL = 1" \
	MASTER_CUSTOM_GOALS="5 ec4_1: \$ec(4,1)|6 ec5_4: \$ec(5,4)" \
	MOUNT_EXTRA_CONFIG="sfscachemode=NEVER" \
	USE_RAMDISK=YES \
	setup_local_empty_saunafs info

nr_of_running_chunkservers=15
cd ${info[mount0]}

# Produce first version chunks
dd if=/dev/zero of=file bs=1k count=5k
saunafs setgoal ec4_1 file
if is_windows_system; then
	sleep 5
fi
while (( $(saunafs fileinfo file | grep -c copy) < 6 )); do # 1 [goal1] + 5 [ec4_1]
	sleep 1
done
saunafs setgoal ec5_4 file
if is_windows_system; then
	sleep 5
fi
while (( $(saunafs fileinfo file | grep -c copy) < 15 )); do # 1 [goal1] + 5 [ec4_1] + 9 [ec5_4]
	sleep 1
done
sleep 2
# Overwrite the file
file-overwrite file
if is_windows_system; then
	sleep 5
fi
# Stop all chunkservers
for_chunkservers stop {0..14}

cs_list=($(find_first_chunkserver_with_chunks_matching "chunk_????????????????_????????.???"))
for_chunkservers start ${cs_list[@]}
MESSAGE="Validating goal 1 chunk" expect_success file-validate file
for_chunkservers stop ${cs_list[@]}

cs_list[0]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_1_of_4_1*.???")
cs_list[1]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_2_of_4_1*.???")
cs_list[2]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_3_of_4_1*.???")
cs_list[3]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_4_of_4_1*.???")
for_chunkservers start ${cs_list[@]}
MESSAGE="Validating ec(4,1) parts of chunk" file-validate file

for_chunkservers stop ${cs_list[0]}
cs_list[0]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_5_of_4_1*.???")
for_chunkservers start ${cs_list[0]}
MESSAGE="Validating ec(4,1) parity of chunk" file-validate file
for_chunkservers stop ${cs_list[@]}

cs_list[0]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_1_of_5_4*.???")
cs_list[1]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_2_of_5_4*.???")
cs_list[2]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_3_of_5_4*.???")
cs_list[3]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_4_of_5_4*.???")
cs_list[4]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_5_of_5_4*.???")
for_chunkservers start ${cs_list[@]}
MESSAGE="Validating ec(5,4) parts of chunk" file-validate file

for_chunkservers stop ${cs_list[1]}
for_chunkservers stop ${cs_list[2]}
for_chunkservers stop ${cs_list[3]}
for_chunkservers stop ${cs_list[4]}
cs_list[1]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_6_of_5_4*.???")
cs_list[2]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_7_of_5_4*.???")
cs_list[3]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_8_of_5_4*.???")
cs_list[4]=$(find_first_chunkserver_with_chunks_matching "chunk_ec2_9_of_5_4*.???")
for_chunkservers start ${cs_list[1]}
for_chunkservers start ${cs_list[2]}
for_chunkservers start ${cs_list[3]}
for_chunkservers start ${cs_list[4]}
MESSAGE="Validating ec(5,4) parity parts of chunk" file-validate file
