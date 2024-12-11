#!/bin/bash

dropCache() {
	echo "Dropping cache."
	sudo sync
	{ echo 3 | sudo tee /proc/sys/vm/drop_caches; } &>/dev/null
	sleep 5
}
