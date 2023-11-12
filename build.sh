#!/bin/bash
if [ ! -d "build" ]; then
	meson setup build
	# meson init --name oxbow_libfs -f --build
	# meson init --name oxbow_libfs -l c -f src
fi
# meson compile -C build
meson compile -vC build
# meson test -C build
