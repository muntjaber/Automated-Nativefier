#!/usr/bin/env bash

# STYLING CONVENTION: If built-in variable, do not use curly braces, e.g., use $REPLY, not ${REPLY}

THIS="$(echo "$0" | awk -F/ '{print $NF}')"
BUILD_DIR="."

function say() {
    printf "\n%s" "$1"
}

function prepare() {
    mkdir -p "${BUILD_DIR}/${pkgname}" && 
    pushd "${BUILD_DIR}/${pkgname}"
}

function cleanup() {
    rm -fr "${BUILD_DIR:?}/${pkgname}"
    exit 0
}

trap cleanup SIGINT

function failed() {
    echo "Exiting due to $(echo "$1" | tr '[:upper:]' '[:lower:]')"
    exit 1
}

function prompt_pkgname() {
    prompt='Enter package name (executable): '
    if [ -z "${pkgname}" ]; then
        read -rp "${prompt}"
    else
        read -rp "${prompt}" -ei "$(echo "${pkgname}" | sed -E 's/-nativefier//g')"
    fi
    pkgname="$REPLY"

    if [ -n "${pkgname}" ]; then
        pkgname="$(echo "${REPLY}-nativefier" | tr '[:upper:]' '[:lower:]' | sed -E 's/^[^a-zA-Z]+|\s//g')"
    fi
}

function prompt_name() {
    prompt='Enter application name: ' 
    if [ -z "${name}" ]; then
        read -rp "${prompt}"
    else
        read -rp "${prompt}" -ei "${name}"
    fi
    name="$REPLY"
}

function prompt_url() {
    prompt='Enter URL: ' 
    if [ -z "${url}" ]; then
        read -rp "${prompt}"
    else
        read -rp "${prompt}" -ei "${url}"
    fi
    url="$REPLY"
}

function prompt_desc() {
    prompt='Enter description: ' 
    if [ -z "${desc}" ]; then
        read -rp "${prompt}"
    else
        read -rp "${prompt}" -ei "${desc}"
    fi
    desc="$REPLY"
}

function prompt_arguments() {
    if [ "${#nativefier_parsed_arguments[*]}" -lt 1 ]; then
        return 0
    fi

    prompt='Enter arguments: '
    read -rp "${prompt}" -ei "${nativefier_parsed_arguments[*]}"
    
    nativefier_parsed_arguments=()
    if [ -n "$REPLY" ]; then
        tell-nativefier "$(echo "$REPLY" | sed -Ee 's/\s[^-]{2}/::&/g' \
            -e 's/::\s+/::/g' \
            -e 's/\s{2,}/ /g' \
            -e 's/\s/,/g' \
            -e 's/(^|,)-+/\n/g' \
            -e 's/::/ /g'\
            )"
    fi
}

function confirm() {
    while [ -z "${pkgname}" ]; do prompt_pkgname; done
    while [ -z "${name}" ]; do prompt_name; done
    if [ -z "${desc}" ]; then prompt_desc; fi
    while [ -z "${url}" ]; do prompt_url; done

    printf '\n'
    printf "%-25s %-10s\n" 'Packange Name:' "${pkgname}"
    printf "%-25s %-10s\n" 'Application Name:' "${name}"
    printf "%-25s %-10s\n" 'Description:' "${desc}"
    printf "%-25s %-10s\n" 'URL:' "${url}"
    if [ "${#nativefier_parsed_arguments[*]}" -gt 0 ]; then
        printf "%-25s %-10s\n" 'Arguments:' "${nativefier_parsed_arguments[*]}"
    fi
    echo -n 'Does this look correct? [y/N]: '
    read -rsn 1

    if echo "$REPLY" | grep -qi '^y$'; then
        return 0
    else
        return 1
    fi
}

function list-installed() {
    shopt -s nullglob
    for directory in /usr/share/*; do
        if echo "${directory}" | grep -iq '.*-nativefier$'; then
            basename "${directory}"
        fi
    done
}

function uninstall() {
    if [ -z "$1" ]; then
        say 'What do you want to uninstall?'
        echo "Run '${THIS} --list' to see installed apps."
        return 0
    fi

    if ! list-installed | grep -ie "$1$"; then
        echo "($1) is not installed.";
        return 0
    fi

    if [ -z "${UNATTENDED}" ]; then
        echo -n "Do you really want to delete $1? [y/N]: ";
        read -rsn 1
        echo
    else
        REPLY='y'
    fi

    if echo "$REPLY" | grep -qi '^y$'; then
        sudo rm -f "/usr/bin/$1"
        sudo rm -fr "/usr/share/$1" 
        sudo rm -f "/usr/share/applications/$1.desktop"
        sudo rm -f "/usr/share/pixmaps/$1.png"

        say "$1 uninstalled."
    else
        say 'Aborting...'
    fi
    echo
}

nativefier_arguments=$(nativefier --help | \
    sed '/Usage/,/Options/d'| \
    grep -Evi '(\(macOS only\)|\(windows only\)|(macOS, windows only))' | \
    sed -E '/--help|--version|--name|--platform|--no-overwrite/d' | \
    grep -Eoi '\s(*-{1,2}[a-zA-Z0-9\-]*,?)( <value>| <[a-zA-Z0-9\-]*>| \[[a-zA-Z0-9\-]*\])?' | \
    tr ',' '\n' | sed '/^$/d' | awk '{print $1}'\
)

nativefier_help=$(nativefier --help | sed '/Usage/,/Options/d'| \
            grep -Evi '(\(macOS only\)|\(windows only\)|(macOS, windows only))' | \
            sed -E '/--help|--version|--name|--platform|--no-overwrite/d' | sort)

nativefier_parsed_arguments=()

tell-nativefier() {
    if [ -z "$1" ]; then
        echo "$nativefier_help"
        echo "No argument received."
        exit 1
    fi

    arguments="$(echo "$1" | tr ',' '\n'| sed -E 's/\s+/::/g' | sed 's/^:://g')"
    for arg in ${arguments}; do
        option="$(echo "${nativefier_arguments}" | grep -ie "$(echo "${arg}" | awk -F:: '{print $1}')$")"
        if [ -n "${option}" ]; then
            nativefier_parsed_arguments+=("$(echo "${option}" "$(echo "${arg}" | awk -F:: '{first = $1; $1=""; print $0}' | sed -Ee 's/^\s*//g' -e 's/^-+//g')")")
        fi
    done
}

# Sanitize filename according to the same standard as Nativefier
#
# SOURCE: https://github.com/parshap/node-sanitize-filename/blob/master/index.js
# SOURCE: https://github.com/jiahaog/nativefier/blob/master/src/utils/sanitizeFilename.ts
function sanitize_filename() {
    dirty="$1"
    dirty="$(echo "${dirty}" | sed -E 's/[\/\?<>\\:\*\|":]//g')"
    dirty="$(echo "${dirty}" | LC_ALL=C sed -E 's/[\x00-\x1f\x80-\x9f]//g')"
    dirty="$(echo "${dirty}" | sed -E 's/^\.+$//')"
    dirty="$(echo "${dirty}" | sed -E 's/^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$//i')"
    dirty="$(echo "${dirty}" | sed -E 's/[\. ]+$//')"
    dirty="$(echo "${dirty}" | sed -E 's/[^\x00-\x7F]//g')"                                   # nativefier
    dirty="$(echo "${dirty}" | sed -E 's/[-]{2,}/-/g')"                                       # nativefier
    echo "${dirty}" | sed -E 's/\s//g'                                                        # nativefier
}

function version() {
    echo 'nativefier.sh 1.0.0'
}

function usage() {
    echo 'Usage: nativefier.sh [OPTION]'
    echo
    echo 'Automates the process of Nativefier and installs the resulting electron app.'
    echo
    echo 'Options:'
    echo
    echo " -p, --pkgname PKGNAME            package name (the terminal command to run this app)"
    echo " -n, --name NAME                  name of the app in application launchers"
    echo " -d, --desc DESCRIPTION           describe the purpose of this app (used by application launchers)"
    echo " -u, --url URL                    the URL of the Web page to convert"
    echo " -N, --nativefier 'ARG'           pass arguments to the Nativefier process directly"
    echo " --uninstall PKGNAME              uninstall a nativefier app"
    echo " --list                           list package name for all installed nativefier apps"
    echo " --args                           print all passable arguments to the Nativefier process"
    echo " --help                           display this help and exit"
    echo " --version                        output version information and exit"
    echo
    echo 'Examples:'
    echo
    echo "${THIS} --nativefier 'maximize,tray start-in-tray,single-instance' "
}

if ! command -v npm >/dev/null 2>&1; then
	echo 'npm missing.'
	exit 1
fi

if [ "$#" -gt 0 ]; then
    options=$(getopt -n "${THIS}" -o p:n:d:u:yN:h --long pkgname:,name:,desc:,url:,list,uninstall::,nativefier:,help,args,version -- "$@")
    eval set -- "$options"
    while :; do
        case $1 in
            -p|--pkgname)
                if [ -n "$2" ]; then
                    pkgname="$(echo "$2"-nativefier | tr '[:upper:]' '[:lower:]' | sed -E 's/^[^a-zA-Z]+|\s//g')"
                fi
                shift 2; continue
                ;;
            -n|--name)
                name="$2"
                shift 2; continue
                ;;
            -d|--desc)
                desc="$2"
                shift 2; continue
                ;;
            -u|--url)
                url="$2"
                shift 2; continue
                ;;
            --list)
                list-installed
                exit 0
                ;;
            --uninstall)
                if echo "${options}" | grep -iqe '\-y'; then
                    UNATTENDED='y'
                fi
                
                shift 2
                uninstall "$(echo "$2" | sed 's/^-.*//g')"
                exit 0
                ;;
            -y)
                if [ -z "${pkgname}" ]; then failed 'missing package name'; fi
                if [ -z "${name}" ]; then failed 'missing app name'; fi
                if [ -z "${url}" ]; then failed 'missing url'; fi

                UNATTENDED='y'
                sudo -v
                shift; continue
                ;;
            -N|--nativefier)
                tell-nativefier "$2"
                shift 2; continue
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --args)
                echo "$nativefier_help"
                exit 0
                ;;
            --version)
                version
                exit 0
                ;;
            --)
                break
                ;;
            *)
                printf "Unknown option: (%s).\n" "$1"
                usage
                exit 1
                ;;
        esac
    done
    eval set -- "$@"
else
    prompt_pkgname
    prompt_name
    prompt_desc
    prompt_url
fi

if [ -z "${UNATTENDED}" ]; then
    confirm
    while [ $? -gt '0' ]; do
        printf '\n\n'

        prompt_pkgname
        prompt_name
        prompt_desc
        prompt_url
        prompt_arguments
        confirm

    done
fi

if ! command -v nativefier >/dev/null 2>&1; then
	say 'nativefier missing.'
	say 'Installing nativefier...'
	sudo npm install -g nativefier
fi

##############################
######## PREPARATION #########
##############################
UNATTENDED='y'
say 'Removing old version (if any).'; say
uninstall "${pkgname}"

prepare

##############################
###### CREATE EXECUTABLE #####
##############################
cat > "${pkgname}" << EOF || failed 'Could not create executable'
#!/usr/bin/env bash
exec electron "/usr/share/${pkgname}" "\$@"
EOF

##############################
##### CONVERT TO ELECTRON ####
##############################
if ! nativefier \
	--name "${name}" \
    --verbose \
    ${nativefier_parsed_arguments[*]} \
	"${url}"; then

    failed 'Nativefier failed'
fi

pkgsrc=$(echo "$(sanitize_filename "${name}")-linux-"*)
settings="${pkgsrc}/resources/app/nativefier.json"
appname=$(tr ',' '\n' < "${settings}" | sed "s/\"name\":\".*\"/\"name\":\"${name}\"/" | tr '\n' ',')
echo "${appname}" > "${settings}"

##############################
######## DESKTOP ENTRY #######
##############################
set -x
gendesk --pkgname "${pkgname}" --name "${name}" --pkgdesc "${desc}" --icon="${pkgname}" -n -f || failed 'gendesk failed'

##############################
#### INSTALLING THE APP ######
##############################

# The icon is used for the system tray and is expected to be the in app directory.
cp "${pkgsrc}/resources/app/icon.png" "${pkgname}.png"
sudo cp -r --remove-destination "${pkgsrc}/resources/app" "/usr/share/${pkgname}"
sudo chmod -R 775 "/usr/share/${pkgname}"
sudo install -Dm 775 -t "/usr/bin/" "${pkgname}"
sudo install -Dm 644 -t "/usr/share/applications/" "${pkgname}.desktop"
sudo install -Dm 644 -t "/usr/share/pixmaps/" "${pkgname}.png"

##############################
######### CLEAN UP ###########
##############################

popd
cleanup
