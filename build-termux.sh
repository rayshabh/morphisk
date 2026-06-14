#!/usr/bin/env bash

set -e

pr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
ask() {
	local y
	for ((n = 0; n < 3; n++)); do
		pr "$1 [y/n]"
		if read -r y; then
			if [ "$y" = y ]; then
				return 0
			elif [ "$y" = n ]; then
				return 1
			fi
		fi
		pr "Asking again..."
	done
	return 1
}

pr "Ask for storage permission"
until
	yes | termux-setup-storage >/dev/null 2>&1
	ls /sdcard >/dev/null 2>&1
do sleep 1; done
if [ ! -f ~/.rvmm_"$(date '+%Y%m')" ]; then
	pr "Setting up environment..."
	yes "" | pkg update -y && pkg upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" && pkg install -y git curl jq openjdk-17 zip
	: >~/.rvmm_"$(date '+%Y%m')"
fi
mkdir -p /sdcard/Download/morphisk/

if [ -d morphisk ] || [ -f config.toml ]; then
	if [ -d morphisk ]; then cd morphisk; fi
	pr "Checking for morphisk updates"
	git fetch
	if git status | grep -q 'is behind\|fatal'; then
		pr "morphisk is not synced with upstream."
		pr "Cloning morphisk. config.toml will be preserved."
		cd ..
		cp -f morphisk/config.toml .
		rm -rf morphisk
		git clone https://github.com/rayshabh/morphisk --recurse --depth 1
		mv -f config.toml morphisk/config.toml
		cd morphisk
	fi
else
	pr "Cloning morphisk."
	git clone https://github.com/rayshabh/morphisk --depth 1
	cd morphisk
	sed -i '/^enabled.*/d; /^\[.*\]/a enabled = false' config.toml
	grep -q 'morphisk' ~/.gitconfig 2>/dev/null ||
		git config --global --add safe.directory ~/morphisk
fi

[ -f ~/storage/downloads/morphisk/config.toml ] ||
	cp config.toml ~/storage/downloads/morphisk/config.toml

if ask "Open rvmm-config-gen to generate a config?"; then
	am start -a android.intent.action.VIEW -d https://rayshabh.github.io/rvmm-config-gen/
fi
printf "\n"
until
	if ask "Open 'config.toml' to configure builds?\nAll are disabled by default, you will need to enable at first time building"; then
		am start -a android.intent.action.VIEW -d file:///sdcard/Download/morphisk/config.toml -t text/plain
	fi
	ask "Setup is done. Do you want to start building?"
do :; done
cp -f ~/storage/downloads/morphisk/config.toml config.toml

./build.sh

cd build
PWD=$(pwd)
for op in *; do
	[ "$op" = "*" ] && {
		pr "glob fail"
		exit 1
	}
	mv -f "${PWD}/${op}" ~/storage/downloads/morphisk/"${op}"
done

pr "Outputs are available in /sdcard/Download/morphisk folder"
am start -a android.intent.action.VIEW -d file:///sdcard/Download/morphisk -t resource/folder
sleep 2
am start -a android.intent.action.VIEW -d file:///sdcard/Download/morphisk -t resource/folder
