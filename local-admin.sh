#!/usr/bin/env bash

readonly VERSION="0.1"
readonly GOOD_EXIT=1
readonly BAD_EXIT=2
readonly HELP_COMMAND="help"
readonly UPDATE_COMMAND="update"
readonly OPTIMIZE_DNFCONF_COMMAND="Change dnf.conf"
readonly INSTALL_DEVELOPMENT_PACKAGES_COMMAND="Install Packages for Development"
readonly INSTALL_DEVELOPMENT_GROUPS_COMMAND="Install Package Groups for Development"
readonly INSTALL_ADMIN_PACKAGES_COMMAND="Install Packages for Administration"
readonly INSTALL_ADMIN_GROUPS_COMMAND="Install Package Groups for Administration"
readonly INSTALL_MISC_PACKAGES_COMMAND="Install Various Packages"
readonly INSTALL_MISC_GROUPS_COMMAND="Install Various Package Groups"
readonly INSTALL_RPM_FUSION_COMMAND="Enable RPM Fusion (Free/Nonfree)"
readonly INSTALL_GCHROME_COMMAND="Install Google Chrome"
readonly SYSTEM_INFO_COMMAND="System Info"
readonly QUIT_COMMAND="Quit"

echo_error() { >&2 echo "$@"; exit ${BAD_EXIT}; }

command_missing() {
	local param=$1	
	{ type "$param" > /dev/null 2>&1; } && { return 1; } || { return 0; } 
}

write_to_file() {
	local line=$1
	local file_name=$2
	su -c "echo '${line}' | tee -a '${file_name}'"
}

check_user() {
	if [[ $EUID -eq 0 ]]; then 
		echo_error "This script must not be run as root" 
	fi
}

check_commands() {
	if command_missing "tee"; then
		echo_error "tee command not found"	
	fi
}

confirm()
{
	local prompt=$*
	local yes="YES"
	local no="NO"
	local cancel="CANCEL"
	echo "${prompt}"
	select resp in "${yes}" "${no}" "$cancel"; do
    		case "${resp}" in
        		"${yes}") echo "You choice is $yes"; return 0;;
        		"${no}") echo "You choice is $no"; return 1;;
			"${cancel}") echo "You choice is $cancel"; exit $GOOD_EXIT;;
			*) echo "invalid option $REPLY";;
    		esac
	done
}

install_dnf_package()
{
	local package_name="$1"
	echo "Attempting to install $package_name"
	su -c "bash -c 'dnf install ${package_name} -y'"
}

install_dnf_packages()
{
	local packages=("$@")
	for item in "${packages[@]}"; do
		if confirm "Install ${item}"; then
			install_dnf_package ${item}
		fi
	done
}

install_dnf_group()
{
	local group_name="$*"
	echo "Attempting to install $group_name"
	su -c "bash -c 'dnf groupinstall \"${group_name}\"'"
}

install_dnf_groups()
{
	local groups=("$@")
	for item in "${groups[@]}"; do
		if confirm "Install ${item}"; then
			install_dnf_group ${item}
		fi
	done
}

do_help_command() { printf "local admin scripts\nversion %s\n" ${VERSION}; }

do_update_command() { 
	if confirm "Continue with updating?"; then 
		{ su -c "bash -c 'dnf update -y'" || echo_error "Failed to update" && echo "Done"; }
	fi
}

do_optimize_dnfconf_command() {
	local file_name="/etc/dnf/dnf.conf"
	printf "Current contents of $file_name is as given below.\n"
	tail $file_name
	echo	
	if confirm "Do you want to edit it?"; then
		declare -a lines=("keepcache=true" "deltarpm=true" "fastestmirror=true")
		for line in "${lines[@]}"; do
	   		if confirm "Add $line to the file?"; then
				write_to_file "$line" "$file_name"			
			fi
		done
	fi		
}

do_install_development_packages()
{
	declare -a packages=("kernel-headers" \
				"kernel-devel" \
				"kernel-tools" \
				"ncurses-devel" \
				"gdbm-devel" \
				"gtk2-devel" \
				"gtk3-devel" \
				"cvs")
	install_dnf_packages "${packages[@]}"
}

do_install_development_groups()
{
	declare -a groups=("Development Tools" \
				"Development Libraries" \
				"C Development Tools and Libraries" \
				"Editors" \
				"Fedora Eclipse" \
				"RPM Development Tools" \
				"Engineering and Scientific" \
				"Development and Creative Workstation" \
				"Authoring and Publishing")
	install_dnf_groups "${groups[@]}"
}

do_install_admin_packages()
{
	declare -a packages=("mc" \
				"gnome-commander" \
				"tree" \
				"dialog" \
				"sysstat" \
				"htop" \
				"glances" \
				"fedora-workstation-repositories")
	install_dnf_packages "${packages[@]}"
}

do_install_admin_groups()
{
	declare -a groups=("Administration Tools" \
				"System Tools" \
				"Headless Management" \
				"Security Lab" \
				"Text-based Internet")
	install_dnf_groups "${groups[@]}"
}

do_install_misc_packages()
{
	declare -a packages=("stockfish" \
				"pychess" \
				"youtube-dl" \
				"vlc" \
				"gstreamer-plugins-base " \
				"gstreamer1-plugins-base" \
				"gstreamer-plugins-bad" \
				"gstreamer-plugins-ugly" \
				"gstreamer1-plugins-ugly" \
				"gstreamer-plugins-good-extras" \
				"gstreamer1-plugins-good" \
				"gstreamer1-plugins-good-extras" \
				"gstreamer1-plugins-bad-freeworld" \
				"ffmpeg" \
				"gstreamer-ffmpeg")
	install_dnf_packages "${packages[@]}"
}

do_install_misc_groups()
{
	declare -a groups=("LibreOffice" \
				"Office/Productivity" \
				"Education Software")
	install_dnf_groups "${groups[@]}"
}

do_install_rpm_fusion()
{
	install_dnf_package "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"
	install_dnf_package "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
}

do_install_gchrome()
{
	su -c "bash -c 'dnf config-manager --set-enabled google-chrome && dnf update -y && dnf install -y google-chrome-stable'"
}

do_system_info_command()
{
	local separator="---------------------"
	local user=`echo $USER`
	local homedir=`echo $HOME`
	local free_space=$(df -h /)
	local free_mem=$(free -m)
	local swappiness=$(cat /proc/sys/vm/swappiness)
	printf "SYSTEM INFO\n%s\nUser: %s\n%s\nHome: %s\n%s\nDisk space: \n%s\n%s\nMemory: \n%s\n%s\nSwappiness: %s\n%s\n" \
							"$separator" \
							"$user" \
							"$separator" \
							"$homedir" \
							"$separator" \
							"$free_space" \
							"$separator" \
							"$free_mem" \
							"$separator" \
							"$swappiness" \
							"$separator"
}

do_quit_command() { echo "Exiting the script"; exit ${GOOD_EXIT}; }

main()
{
	check_user
	check_commands
	PS3='Select number of the command to run: '
	local commands=( "${HELP_COMMAND}" \
				"${UPDATE_COMMAND}" \
				"${OPTIMIZE_DNFCONF_COMMAND}" \
				"${INSTALL_DEVELOPMENT_PACKAGES_COMMAND}" \
				"${INSTALL_DEVELOPMENT_GROUPS_COMMAND}" \
				"${INSTALL_ADMIN_PACKAGES_COMMAND}" \
				"${INSTALL_ADMIN_GROUPS_COMMAND}" \
				"${INSTALL_MISC_PACKAGES_COMMAND}" \
				"${INSTALL_MISC_GROUPS_COMMAND}" \
				"${INSTALL_RPM_FUSION_COMMAND}" \
				"${INSTALL_GCHROME_COMMAND}" \
				"${SYSTEM_INFO_COMMAND}" \
				"${QUIT_COMMAND}" )
	select command in "${commands[@]}"; do
    		case $command in
        		${HELP_COMMAND})
            			do_help_command;
				break
            			;;
        		${UPDATE_COMMAND})
            			do_update_command;
				break
            			;;
        		${OPTIMIZE_DNFCONF_COMMAND})
            			do_optimize_dnfconf_command;
				break
            			;;
        		${INSTALL_DEVELOPMENT_PACKAGES_COMMAND})
            			do_install_development_packages;
				break
            			;;
        		${INSTALL_DEVELOPMENT_GROUPS_COMMAND})
            			do_install_development_groups;
				break
            			;;
        		${INSTALL_ADMIN_PACKAGES_COMMAND})
            			do_install_admin_packages;
				break
            			;;
        		${INSTALL_ADMIN_GROUPS_COMMAND})
            			do_install_admin_groups;
				break
            			;;
        		${INSTALL_MISC_PACKAGES_COMMAND})
            			do_install_misc_packages;
				break
            			;;
        		${INSTALL_MISC_GROUPS_COMMAND})
            			do_install_misc_groups;
				break
            			;;
        		${INSTALL_RPM_FUSION_COMMAND})
            			do_install_rpm_fusion;
				break
            			;;
        		${INSTALL_GCHROME_COMMAND})
            			do_install_gchrome;
				break
            			;;
        		${SYSTEM_INFO_COMMAND})
            			do_system_info_command;
				break
            			;;
        		${QUIT_COMMAND})
				do_quit_command
            			;;
        		*) echo "invalid option $REPLY";;
    		esac
	done
	read -p "Press RETURN to exit the script"
}

main $*

exit $?