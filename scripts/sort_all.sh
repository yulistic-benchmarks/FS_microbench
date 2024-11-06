#!/bin/bash

printUsage() {
	echo "$(basename $0) <result_file>"
}

sortAll() {

}

# Execute only this script is directly executed. (Not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

	if [ -z $1 ] || [ $1 = "-h" ] || [ $1 = "--help" ]; then
		printUsage
	fi

	sortAll $1

fi
