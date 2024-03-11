if is_windows_system; then
	timeout_set 5 minutes
else
	timeout_set 3 minutes
fi


CHUNKSERVERS=4 \
	MOUNTS=10 \
	MOUNT_EXTRA_CONFIG="sfscachemode=NEVER" \
	USE_RAMDISK=YES \
	setup_local_empty_saunafs info

# Create an empty file on the SaunaFS filesystem with xor3 goal
file="${info[mount0]}/file"
touch "$file"
saunafs setgoal xor3 "$file"

# Create a temporary file with 25 megabytes of generated data
tmpf=$RAMDISK_DIR/tmpf
FILE_SIZE=25M file-generate "$tmpf"

# Run 10 tasks, each of them will copy every tenth kilobyte from the temporary file to the file
# on SaunaFS using 5 concurrent writers and a dedicated mountpoint
for i in {0..9}; do
	(
		file="${info[mount${i}]}/file"
		seq $i 10 $((25*1024-1)) | shuf | expect_success xargs -P5 -IXX \
				dd if="$tmpf" of="$file" bs=1K count=1 seek=XX skip=XX conv=notrunc 2>/dev/null
	) &
done
wait

# Validate the result
MESSAGE="Data is corrupted after writing" expect_success file-validate "$file"

# Validate the parity part
csid=$(find_first_chunkserver_with_chunks_matching 'chunk_xor_1_of_3*')
saunafs_chunkserver_daemon $csid stop

MESSAGE="Parity is corrupted after writing" expect_success file-validate "$file"
