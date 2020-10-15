#!/usr/bin/env bash

# This file auto-generated by: ./development-helpers.bash build-sdk-bootstrapper ; VERSION=v3.75.0; DATE=2020-10-15--12:51

export LC_ALL="en_US.UTF-8"

# HELPERS BEGIN
INSTALLER_VERSION='v3.75.0'
INSTALLER_BUILD_DATE='2020-10-15'
# helpers/arrays.bash
#!/usr/bin/env bash

inArray () {
    # inArray(array_name, needle)
    local -n arr="$1"
    local needle="$2"

    local item
    for item in "${arr[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done

    return 1
}

join () {
    # join(separator, i1, i2, i3...)
    local separator="$1"
    shift

    local string="$( printf "%s" "${@/#/$separator}" )"
    string="${string:${#separator}}" # remove leading separator
    echo "${string}"
}

# helpers/brew.bash
#!/usr/bin/env bash

isBrewPackageInstalled () {
    brew ls --versions $1 &> /dev/null

    return $?
}

# helpers/cache.bash
#!/usr/bin/env bash

USE_CACHE="${USE_CACHE:-"true"}"
CACHE_DIR_PATH="${CACHE_DIR_PATH:-"cache"}"

declare -A CACHE_MANAGER_RETURN_CODES
CACHE_MANAGER_RETURN_CODES=( ["EXISTS"]=0 ["DISABLED"]=1 ["NOT_FOUND_OR_EXPIRED"]=2 )

cacheManager () {
    # cacheManager(timeout_seconds, key)
    #
    # cacheManager uses hashes key, checks whether a file exists in the cache
    # folder $CACHE_DIR_PATH named after that hash and whether its created
    # date is no later than timeout_seconds ago.
    #
    # If such file exists, output its path and returns: $CACHE_MANAGER_RETURN_CODES["EXISTS"].
    # Otherwise output the path to which content to be cached should
    # be stored and returns $CACHE_MANAGER_RETURN_CODES["NOT_FOUND_OR_EXPIRED"].
    # If $USE_CACHE is set to any value other than "true" will always
    # return $CACHE_MANAGER_RETURN_CODES["DISABLED"] and no output.
    #
    # Cache clearing:
    # 
    # The cache clear files in the following cases:
    #
    # * If a file exists for key, but is expired for the desired timeout_seconds
    # cacheManager will remove that file before returning cache path.
    #
    # Cache index:
    #
    # As long as cache is not disabled, for every request made to it, a record will be
    # added to a file named 000-INDEX in the format $hash\t$key (a record won't be added
    # more than once) .
    #
    # Note, since it is up to the program that called cacheManager to actually create
    # the file, a file might be logged to the index but not exist (if for example, the
    # calling program failed to create it).
    #
    # Arguments:
    #
    # timeout_seconds: timeout in seconds.
    # key: completly arbitrary string (can have spaces/tabs, any language chars...)
    #
    # Return codes:
    #
    # 0 cache file retrived and outputted.
    # 1 caching disabled
    # 2 cache file isn't available (either not exists or expired), 
    # target path to store value to outputted.

    local timeout_seconds="$1"
    local key="$2"

    if [[ "$USE_CACHE" != "true" ]]; then
        return "${CACHE_MANAGER_RETURN_CODES["DISABLED"]}"
    fi

    if which shasum &> /dev/null; then
        local cachefile_name=$(echo "$key" | shasum -a 256 | awk '{print $1}')
    else
        local cachefile_name=$(echo "$key" | sha256sum | awk '{print $1}')
    fi

    local cachefile_path="$CACHE_DIR_PATH/$cachefile_name"

    # Output file path
    echo "$cachefile_path"

    if [[ ! -e "$cachefile_path" ]]; then
        local index_file_path="$CACHE_DIR_PATH/000-INDEX"

        if [[ ! -e "$index_file_path" ]]; then
            # If no index file, likely that we don't have cache dir either
            mkdir -p "$CACHE_DIR_PATH"
        fi

        # When we don't find the file, we assume we never created it,
        # add a line to $index_file_path
        echo "${key}"$'\t'"${cachefile_path}" >> "$index_file_path"

        return "${CACHE_MANAGER_RETURN_CODES["NOT_FOUND_OR_EXPIRED"]}"
    fi

    if (( "$(getCurrentTimestamp)" - "$(getFileModifiedDate $cachefile_path)" >= $timeout_seconds )); then
        rm $cachefile_path

        # Note that if expired, we assume a record was added already to
        # $index_file_path

        return "${CACHE_MANAGER_RETURN_CODES["NOT_FOUND_OR_EXPIRED"]}"
    fi

    return "${CACHE_MANAGER_RETURN_CODES["EXISTS"]}"
}

# helpers/command-exists.bash
#!/usr/bin/env bash

commandExists () {
    command -v "$1" >/dev/null 2>&1
}

# helpers/crawler.bash
#!/usr/bin/env bash

USE_CACHE="${USE_CACHE:-"true"}"
CACHE_TARGET="${CACHE_TARGET:-"cache/crawler"}"
CACHE_TIMEOUT_SECS="${CACHE_TIMEOUT_SECS:-$((60 * 60 * 24))}" # seconds

crawlerGetPage () {
    local url="$1"

    local lynx_command=(lynx -dump -hiddenlinks=listonly "$url")

    local content_cache_path # Can't init and assign on same line, otherwise $?
                             #will get the succesful init return value and not
                             # the subshell return code
    content_cache_path=$(cacheManager $CACHE_TIMEOUT_SECS "${lynx_command[*]}")
    local return_code=$?

    if [[ "$return_code" == "${CACHE_MANAGER_RETURN_CODES["DISABLED"]}" ]]; then
        # echo "Cache is disabled"

        "${lynx_command[@]}"
    elif [[ "$return_code" == "${CACHE_MANAGER_RETURN_CODES["NOT_FOUND_OR_EXPIRED"]}" ]]; then
        # echo "Not found or expired"

        local output=$("${lynx_command[@]}")

        cat > "$content_cache_path" <<< "$output"

        cat "$content_cache_path"
    elif [[ "$return_code" == "${CACHE_MANAGER_RETURN_CODES["EXISTS"]}" ]]; then
        # echo "Exists"

        cat "$content_cache_path"
    fi
}

crawlerGetAllPageLinks () {
    local url="$1"

    cat <<< "$(crawlerGetPage "$url")" | platformSed -n '/References/,$p' | tail -n +3 | awk '{print $2}'
}

# helpers/cross-platform-commands.bash
#!/usr/bin/env bash

# The following commands makes sure that we are using the correct commands
# available on the platform we are running on.
#
# They assume the README-OSX.md was followed on OSX devices and required
# packages were installed.

platformReadlink () {
    # Prefer greadlink over readlink - installed by $ brew install coreutils

    local readlink="readlink"

    if commandExists greadlink; then
        readlink="greadlink"
    fi

    "$readlink" "$@"   
}

platformXargs () {
    # Prefer gxargs over xargs - installed by $ brew install findutils 

    local xargs="xargs"

    if commandExists gxargs; then
        xargs="gxargs"
    fi

    "$xargs" "$@"   
}

platformSed () {
    # Prefer gsed over sed - installed by $ brew install gnu-sed

    local sed="sed"

    if commandExists gsed; then
        sed="gsed"
    fi

    "$sed" "$@"   
}

platformTar () {
    # Prefer gtar over tar - installed by $ brew install gnu-tar

    local tar="tar"

    if commandExists gtar; then
        tar="gtar"
    fi

    "$tar" "$@"   
}

platformDu () {
    # Prefer gdu over du

    local du="du"

    if commandExists gcp; then
        du="gdu"
    fi

    "$du" "$@"
}

platformTr () {
    # Prefer gcp over cp

    local tr="tr"

    if commandExists gtr; then
        tr="gtr"
    fi

    "$tr" "$@"
}

platformCp () {
    # Prefer gcp over cp

    local cp="cp"

    if commandExists gcp; then
        cp="gcp"
    fi

    "$cp" "$@"
}

platformGrep () {
    # Prefer ggrep over grep

    local grep="grep"

    if commandExists ggrep; then
        grep="ggrep"
    fi

    "$grep" "$@"
}

# helpers/csv.bash
#!/usr/bin/env bash

csvVals () {
    # Print the values of the given csv string
    echo ${1//,/ }
}

csvIntersection () {
    # Prints the intersection of two csv strings provided as inputs

    # Assumptions:
    #   No way to escape a ,
    #   No sequence of "---" (3 dashes) in any value  

    local -a ar1=$(csvVals $1)
    local -a ar2=$(csvVals $2)

    # Join ar2 into a "---" separated string and wrap it with this string
    local l2
    local l2="---$(join "---" ${ar2[*]})---" # add framing blanks

    local -a result
    local item
    for item in ${ar1[@]}; do
        if [[ $l2 =~ "---$item---" ]] ; then # use $item as regexp
            result+=($item)
        fi
    done

    echo ${result[@]}
}

# helpers/date.bash
#!/usr/bin/env bash

getCurrentYear () {
    date +%Y
}

getUnicodeDate () {
    date +%Y-%m-%d
}

getUnicodeDateTime () {
    date +%Y-%m-%d--%H:%M
}

getUnicodeDateTimeNoColon () {
    date +%Y-%m-%d--%H%M
}

getCurrentTimestamp () {
    date +%s
}

# helpers/docker.bash
#!/usr/bin/env bash

dockerRemoveUntaggedImages () {
    docker images -q --filter "dangling=true" | platformXargs -n1 -r docker rmi
}

dockerQuietStopRemove () {
    local container="$1"

    docker stop "$container" &> /dev/null
    docker rm "$container" &> /dev/null   
}

isDockerRunning () {
    docker ps &> /dev/null
}

dockerAvailableMemory () {
    local available_mem

    if ! available_mem="$(docker info 2> /dev/null | grep Mem )"; then
        >&2 echo "Error: Couldn't determine Docker Available Memory, check whether Docker is running"

        return 1
    fi

    echo "$available_mem" | awk '{print $3}'
}

dockerAvailableGiBMemory () {
    local available_mem available_gib

    if ! available_mem="$(dockerAvailableMemory)"; then
        return 1
    fi

    if ! available_gib="$(echo "$available_mem" | grep "GiB")"; then
        >&2 echo "Error: the memory available for Docker ($available_mem) isn't supported"

        return 1
    fi

    available_gib="$(echo "$available_gib" | sed -e 's/GiB//g')"

    echo "$available_gib"
}

dockerRequireAvailableGiBMemory () {
    local required_gib="$1"

    local available_gib

    if ! available_gib="$(dockerAvailableGiBMemory)"; then
        return 1
    fi

    if [[ "$(echo "$available_gib < $required_gib" | bc)" == 1 ]]; then
        >&2 echo "Error: the memory available for Docker (${available_gib}GiB) doesn't meet the memory requirement (${required_gib}GiB)"

        return 1
    fi

    return 0
}
# helpers/envsubst.bash
#!/usr/bin/env bash

inplaceEnvsubst () {
    # inplaceEnvsubst(source_file[, vars_to_replace])
    #
    # vars_to_replace, if defined, should be in the form '$VAR1 $VAR2...', if empty all
    # the vars will be substituted.
    local source_file="$1"
    local vars_to_replace="$2"

    envsubst "$vars_to_replace" < $source_file > "${source_file}-output"
    mv "${source_file}-output" "$source_file"
}

cpEnvsubst () {
    # inplaceEnvsubst(source_file, destination_file[, vars_to_replace])
    #
    # vars_to_replace, if defined, should be in the form '$VAR1 $VAR2...', if empty all
    # the vars will be substituted.
    local source_file="$1"
    local destination_file="$2"
    local vars_to_replace="$3"

    cp "$source_file" "$destination_file"
    inplaceEnvsubst "$destination_file" "$vars_to_replace"
}

recursiveEnvsubst () {
    # recursiveEnvsubst(source_dir, destination_dir[, vars_to_replace])
    #
    # vars_to_replace, if defined, should be in the form '$VAR1 $VAR2...', if empty all
    # the vars will be substituted.
    local source_dir="$1"
    local destination_dir="$2"
    local vars_to_replace="$3"

    if [ -e "$destination_dir" ]; then
        announceErrorAndExit "recursiveEnvsubst Error: \$destination_dir $destination_dir already exist"
    fi

    cp -r "$source_dir" "$destination_dir"


    template_filler_command='envsubst '
    if [ -n "$vars_to_replace" ]; then
        template_filler_command+="'"$vars_to_replace"' "
    fi
    template_filler_command+='< % > %-output; mv %-output %'

    find "$destination_dir" -type f -print0 | platformXargs -0 -I % /bin/bash -c "$template_filler_command"
}

# helpers/files.bash
#!/usr/bin/env bash

getFileModifiedDate () {
    date -r "$1" +%s
}


# helpers/git.bash
#!/usr/bin/env bash

gitCheckoutMasterRec () {
    rep_path="$1"
    reset_to_origin_origin_master="$2"

    announceMainStep "Checkout master of ${rep_path}"

    pushd .

    cd "$rep_path"

    git checkout master

    if [[ "$reset_to_origin_origin_master" == "true" ]]; then
        git fetch

        git reset --hard origin/master
    fi

    git submodule update --init --recursive

    if [[ -d modules ]]; then
        cd modules
        for submodule in "justdo-shared-pacakges" "justdo-internal-pacakges" "justdo.gridctrl"; do
            if [[ -e "$submodule" ]]; then
                announceStep "Checkout submodule "$submodule" master of ${rep_path}"

                pushd .

                cd "$submodule"

                git checkout master

                if [[ "$reset_to_origin_origin_master" == "true" ]]; then
                    git fetch

                    git reset --hard origin/master
                fi

                popd
            fi
        done
    fi

    popd
}

getCurrentGitBranch () {
    git branch | grep '*' | awk '{print $2}'
}

getLastFileModification () {
    git log -1 --format="%ai" "$1"
}

isCleanGitRep () {
    [ -z "$(git status --porcelain)" ]
}

getContributersEmailsByCommitsCount () {
    git log | grep 'Author:' | sed -e 's/Author: .*<\(.*\)>/\1/' | sort | uniq -c | sort -r
}
# helpers/iwait.bash
#!/usr/bin/env bash

# https://github.com/theosp/osp-dist/blob/master/sys-root/home/theosp/.bash/alias/iwait.sh

iwait () {
    # Usage example:
    #
    #   $ iwait file-name/dir-name ./command-to-execute arg1 arg2...

    # Usage example2, more than one command to execute:
    #
    #   $ iwait file-name/dir-name /bin/bash -c './command-to-execute-2 arg1 arg2...; ./command-to-execute-1 arg1 arg2...; ...'

    watched_paths="$(csvVals "$1")" # Note, if a folder provided symbolic links under it are not traversed.

    shift # All the other arguments are considered the command to execute

    announceStep ">>> iwait first run BEGIN"

    "${@}"

    announceStep ">>> iwait first run DONE"

    # We use while without -m to avoid exit inotifywait from exit/stop watchin
    # the file when move_self happens (this is the way vim saves files)
    #
    # By running the while this way, we re-initializing inotify after every
    # event, this way we know for sure that in cases like move_self based
    # save the new file will be watched in the next itteration.
    while inotifywait -e moved_from -e moved_to -e move_self -e close_write -r $watched_paths; do
        announceStep ">>> iwait action BEGIN"
        "${@}"
        announceStep ">>> iwait action DONE"

        # short sleep for case file was saved by moving temp file (in
        # which case it won't exist for few ms move_self case).
        sleep .1
    done
}

# helpers/meteor.bash
#!/usr/bin/env bash

getPackageFullName () {
    local package_path="$1"

    cat "$package_path" | grep -m 1 name | platformSed -e $'s/\s\+"\\?name"\\?:\s*["\']\(.\+\)["\'].*/\\1/g'
}
# helpers/mongo.bash
#!/usr/bin/env bash

# For now, implemented only for dbs with no auth
# MONGODB_USERNAME="${MONGODB_USERNAME:-}"
# MONGODB_PASSWORD="${MONGODB_PASSWORD:-}"
MONGODB_HOST="${MONGODB_HOST:-127.0.0.1}"
MONGODB_PORT="${MONGODB_PORT:-3001}"
MONGODB_COLLECTION="${MONGODB_COLLECTION:-meteor}"

mongoExecute () {
    mongo "$MONGODB_HOST:$MONGODB_PORT/$MONGODB_COLLECTION"
}

# helpers/paths.bash
#!/usr/bin/env bash

expandPath () {
    platformReadlink -f "$@"
}

isRelativePath () {
    local path="$1"

    if [[ -n "$(csvIntersection "${path:0:1}" "~,/")"  ]]; then
        return 1 # Not relative
    fi

    return 0 # Relative
}

# helpers/recursive-find-replace.bash
#!/usr/bin/env bash

#
# Update packages' package.js api
#
recursiveFindReplace () {
    # recursiveFindRepl-e ace (sed_command, space_separated_find_ops_and_paths, [find_expr_arg1, find_expr_arg2, ...])

    # Env var:
    #
    # TEST: can be either: "false" or "true", any other value will be regarded as "false".
    # if TEST is "true", we'll just print the list of file names that is going to be affected.

    # Example 1:
    #
    #   Replace subdomainA.example.com with subdomainB.example.com in paths: x/y x/z
    #
    #   recursiveFindReplace 's/subdomainA\.example\.com/subdomainB.example.com/g' "x/y x/z" -name "1" -or -name "2" 

    # Example 2:
    #
    #   Replace subdomainA.example.com with subdomainB.example.com in paths: x/y x/z
    #   follow sym links
    #
    #   recursiveFindReplace 's/subdomainA\.example\.com/subdomainB.example.com/g' "-L x/y x/z" -name "1" -or -name "2" 

    local sed_command="$1"
    local space_separated_find_ops_and_paths="$2"
    shift
    shift

    echo
    echo "Sed command (extended regex): $sed_command"
    echo
    if [[ "$TEST" == "true" ]]; then
        echo find $space_separated_find_ops_and_paths \( "$@" \) -type f

        find $space_separated_find_ops_and_paths \( "$@" \) -type f  -print0 | platformXargs -0 -n 1 echo
    else
        find $space_separated_find_ops_and_paths \( "$@" \) -type f  -print0 | platformXargs -0 sed -i -r -e "$sed_command"
    fi
}

# helpers/silent-push.bash
#!/usr/bin/env bash

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}


# helpers/string-formatters.bash
#!/usr/bin/env bash

announceStep () {
    echo
    echo "$(style.info)> $@ $(style.reset)"
    echo
}

announceMainStep () {
    echo
    echo "$(style.importantInfo)>>> $@ $(style.reset)"
    echo
}

announceError () {
    echo
    echo "$(style.error)> Error:$(style.reset) $(style.fcolor 7)$@$(style.reset)"
    echo
}

announceErrorAndExit () {
    announceError $@

    exit 1
}

# helpers/style.bash
#!/usr/bin/env bash

# Based on the bupler lib

style.bold ()
{
    if ! $NO_COLOR; then
        tput bold
    fi

    return 0
}

style.fcolor ()
{
    if ! $NO_COLOR; then
        tput setaf "$1"
    fi

    return 0
}

style.bcolor ()
{
    if ! $NO_COLOR; then
        tput setab "$1"
    fi

    return 0
}

style.error ()
{
    style.fcolor 1
}

style.info ()
{
    style.fcolor 2
}

style.importantInfo ()
{
    style.fcolor 5
}

style.reset ()
{
    if ! $NO_COLOR; then
        tput sgr0
    fi
}

# vim:ft=bash:

# helpers/versions.bash
#!/usr/bin/env bash

getVersionComponents () {
    local version="$1"

    version="$(echo "$version" | platformSed 's/^v//i')"

    version_parts=( ${version//./ } )

    echo "${version_parts[@]}"
}

isVersionHigher () {
    # Exits with 0 if version_1 < version_2
    local version_1="$1"
    local version_2="$2"

    v1_components=( $(getVersionComponents "$version_1") )
    v2_components=( $(getVersionComponents "$version_2") )

    if (( "${v1_components[0]}" > "${v2_components[0]}" )); then
        return 1
    fi

    if (( "${v1_components[0]}" < "${v2_components[0]}" )); then
        return 0
    fi

    if (( "${v1_components[1]}" > "${v2_components[1]}" )); then
        return 1
    fi

    if (( "${v1_components[1]}" < "${v2_components[1]}" )); then
        return 0
    fi

    if (( "${v1_components[2]}" > "${v2_components[2]}" )); then
        return 1
    fi

    if (( "${v1_components[2]}" < "${v2_components[2]}" )); then
        return 0
    fi

    return 1
}

# HELPERS ENDS
export NO_COLOR="${NO_COLOR:-"false"}"

announceMainStep "Installing the JustDo SDK"

echo "Installer version: $INSTALLER_VERSION ($INSTALLER_BUILD_DATE)"
echo

cat <<EOF
------------------------------------------------------------------------------

JUSTDO, INC.
JUSTDO SDK AND JUSTDO SOFTWARE AGREEMENT

Copyright $(getCurrentYear) JustDo, Inc.

1) This software is subject to JustDo Inc.'s:

* On-Premises Setup - Terms and Conditions: https://justdo.com/on-premises-terms-and-conditions
* Copyright Notice: https://justdo.com/copyright-notice
* Privacy policy: https://justdo.com/privacy-policy

2) THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

EOF

echo -n "By typing 'agree' you are agreeing to *all* the above points. Type anything else
to cancel. [agree, cancel] : "

read ans
if [[ "$ans" != "agree" ]]; then
    echo
    announceError "Agreement declined terminating installation."
    echo

    exit 1
fi

echo
echo -n ">>> Fill in your email address for Security Updates and General JustDo SDK announcements [Press enter to skip] : "

read email
echo
if [[ -n "$email" ]]; then
    if curl -X POST -d "email=$email" https://justdo.com/sdk-register-developer &> /dev/null; then
        announceStep "Email added successfully"
    else
        announceError "Failed to add the email to the SDK mailing list"
    fi
fi


#
# Ensure default folder sdk folder name (the one extracted from the launcher tar)
#
justdo_sdk_launcher_extracted_folder_name="justdo-sdk-launcher"
if [[ -e "$justdo_sdk_launcher_extracted_folder_name" ]]; then
    announceErrorAndExit "A file or folder named '$justdo_sdk_launcher_extracted_folder_name' exists in the current folder, remove it and run again"
fi

#
# Ensure output folder target is available
#
output_folder="justdo"
if [[ -e "$output_folder" ]]; then
    announceErrorAndExit "A file or folder named '$output_folder' already exists in the current folder, remove it and run again"
fi

#
# Ensure Docker is running
#
if ! isDockerRunning; then
    announceError "Docker isn't running. Please install & run Docker, and try again."

    echo "Note: if Docker is installed, you might have no permission to run it as '$USER'. Try running the following:"
    echo
    echo "$ sudo groupadd docker"
    echo "$ sudo usermod -aG docker $USER"
    echo
    echo "You might need to relogin or restart your machine, for the above to take effect"

    exit 1
fi

if ! dockerRequireAvailableGiBMemory 2.9; then 
    announceErrorAndExit "On Mac, go to: Docker preferences' Resources tab and set a Memory value >= 3GiB"

    exit 1
fi

#
# Determine OS
#
UNAME=$(uname)
# Check to see if it starts with MINGW.
if [ "$UNAME" ">" "MINGW" -a "$UNAME" "<" "MINGX" ] ; then
    echo "At the moment we are not supporting installation on Windows"
    exit 1
fi
if [ "$UNAME" != "Linux" -a "$UNAME" != "Darwin" ] ; then
    echo "Sorry, this OS is not supported yet via this installer."
    exit 1
fi
is_linux="false"
is_mac="false"
if [[ "$UNAME" == "Darwin" ]]; then
    is_mac="true"
elif [[ "$UNAME" == "Linux" ]]; then
    is_linux="true"
fi

#
# Determine whether brew is intalled
#
if [[ "$is_mac" == "true" ]]; then
    if ! commandExists brew; then
        announceErrorAndExit "We require brew ( https://brew.sh/ ) to be installed in order to install the SDK"
    fi
fi

#
# Ensure we got Bash >= v4.3
#
bash_version_arr=( ${BASH_VERSION//./ } )
if ! (( ( "${bash_version_arr[0]}" >= 4 && "${bash_version_arr[1]}" >= 3 ) || ( "${bash_version_arr[0]}" > 4 ) )); then
    if [[ "$is_mac" == "true" ]]; then
        # For mac we help the users a little bit more
        announceStep "Your current bash version ($BASH_VERSION) isn't supported by the SDK."

        announceStep "Do you want us to help you upgrade your bash? [y,n]"

        read ans
        if [[ "$ans" == "n" ]]; then
            announceErrorAndExit "Bash >= v4.3 is required"
        fi

        announceStep "Installing bash with brew:"

        brew install bash

        announceStep "Adding bash to your /etc/shells (root permission required):"

        sudo bash -c 'echo /usr/local/bin/bash' >> /etc/shells

        announceStep "Changing your shell to the newly installed bash"
        chsh -s /usr/local/bin/bash

        announceStep "Do the following:"

        echo '* Go to "System Preferences" > "Users & Groups"'
        echo '* Click the "Lock" icon and authenticate'
        echo '* Right-click the your user icon in the users menu on the left and select "Advanced Options".'
        echo '* Change the value for "Login shell" to /usr/local/bin/bash'
        echo '* Restart your terminal'

        announceMainStep "Rerun the JUSTDO SDK installer command when you completed the above."

        exit 1
    else
        announceErrorAndExit "Bash >= v4.3 is required"
    fi
fi

#
# If mac, install all required brew packages
#
if [[ "$is_mac" == "true" ]]; then
    announceStep "Look for all the brew packages required by the SDK, install the missing ones"

    # To have: mongodb-community
    brew tap mongodb/brew

    required_brew_packages=(
        "coreutils" # coreutils (needed for greadlink)
        "findutils" # findutils (needed for gxargs)
        "gnu-sed" # gnu-sed (needed for gsed)
        "grep" # grep (needed for ggrep)
        "gnu-tar" # gnu-tar
        "mongodb-community" # Note, we are using mongo for some support tool, the environment db will be installed in a docker container, and won't use your environment's mongo.
        "tree" # tree
        "wget" # wget
    )

    for package in "${required_brew_packages[@]}"; do
        if ! isBrewPackageInstalled "$package"; then
            announceStep "Installing package: $package"

            brew install "$package"
        fi
    done

    # gettext needs special treatment
    if ! isBrewPackageInstalled gettext; then
        announceStep "Installing package gettext"

        brew install gettext
    fi

    # In brew, gettext is keg-only and must be linked with --force
    # The essential tool we need from gettext is envsubst, if we can't find it,
    # we force gettext linking.
    if ! commandExists gettext; then
        announceStep "Linking gettext"
        brew link --force gettext
    fi

    announceStep "All brew required brew packages are installed"
fi

#
# If mac, create /var folder
#
DEFAULT_VAR_FOLDER="/var/justdo"
if [[ "$is_mac" == "true" ]]; then
    DEFAULT_VAR_FOLDER="/private/var/justdo"

    if [[ ! -d "$DEFAULT_VAR_FOLDER" ]]; then
        announceStep "Creating JustDo's SDK data folder under: $DEFAULT_VAR_FOLDER (root permission required)"

        sudo mkdir -p "$DEFAULT_VAR_FOLDER"

        sudo chmod a+rwx "$DEFAULT_VAR_FOLDER"
    fi
fi

#
# Look for the current stable sdk-launcher tag
#
announceStep "Download SDK console $sdk_launcher_version"
sdk_launcher_url="https://justdo-sdk-launcher.s3-us-west-2.amazonaws.com"
sdk_launcher_version="$(curl "$sdk_launcher_url/.branches" 2>/dev/null | grep "stable" | awk '{print $2}')"
if [[ -z "$sdk_launcher_version" ]]; then
    announceErrorAndExit "Failed to find the current stable JustDo SDK console version"
fi

sdk_launcher_file_path="$(curl "$sdk_launcher_url/.index" 2>/dev/null | grep "$sdk_launcher_version" | awk '{print $2}')"
if [[ -z "$sdk_launcher_file_path" ]]; then
    announceErrorAndExit "Failed to find the current stable JustDo SDK url"
fi

if ! wget -q "$sdk_launcher_url/$sdk_launcher_file_path" -O "$sdk_launcher_file_path"; then
    announceErrorAndExit "Failed to download JustDo's SDK console"
fi

#
# Prepare /etc/hosts
#
if ! cat /etc/hosts | grep "local.justdo.com" &> /dev/null; then
    announceStep "/etc/hosts isn't configured with the SDK domains, adding the SDK domains to /etc/hosts . Root permission required"

    etc_hosts_line="127.0.0.1 local.justdo.com app-local.justdo.com"
    echo "$etc_hosts_line" | sudo tee -a /etc/hosts &> /dev/null

    announceStep "The following line added to your /etc/hosts file"

    echo "$etc_hosts_line"
    echo
fi

#
# Extract the SDK launcher and put it in the target output folder
#
announceStep "Extract the SDK console"
tar -xjf "$sdk_launcher_file_path"

mv "$justdo_sdk_launcher_extracted_folder_name" "$output_folder"

rm "$sdk_launcher_file_path"

pushd .
cd "$output_folder"
    #
    # Prepare SDK configuration
    #
    announceMainStep "Prepare SDK configuration"
    mv "default-config.bash" "config.bash"

    changes_to_config_file=()

    announceStep "Set development_mode option to true"
    changes_to_config_file+=('s/development_mode="false"/development_mode="true"/')

    # announceStep "Enable plugins (Plugins folder is under: /plugins)"
    # changes_to_config_file+=('s/WEB_APP_PLUGINS_MODE="off"/WEB_APP_PLUGINS_MODE="on"/')

    if [[ "$is_mac" == "true" ]]; then
        announceStep "Set JustDo's global data folder to: $DEFAULT_VAR_FOLDER"

        changes_to_config_file+=('s,VAR_PATH="/var/justdo",VAR_PATH="'$DEFAULT_VAR_FOLDER'",')

        announceStep "Set WEB_APP_PROXIED_METEOR_WAREHOUSE option to true"
        changes_to_config_file+=('s/WEB_APP_PROXIED_METEOR_WAREHOUSE="false"/WEB_APP_PROXIED_METEOR_WAREHOUSE="true"/')
    fi

    for config_change in "${changes_to_config_file[@]}"; do
        if ! platformSed -i "$config_change" "config.bash"; then
            announceErrorAndExit "Couldn't apply a change to the config file (config.bash): $config_change"
        fi
    done

    announceMainStep "SDK configuration (config.bash) is ready"

    # We don't want the following $ justdo update; and $ justdo set-current-folder-as-main-setup
    # to trigger reinstall, we do it once, ourself after.
    export JUSTDO_SKIP_REINSTALL="true"

    # No need to check for updates in that stage
    export SKIP_JUSTDO_UPDATE_CHECK="true"

    #
    # Obtain the stable Bundle
    #
    if [[ "$SDK_UTILS_ONLY" != "true" ]]; then
        announceMainStep "SDK download the current stable JustDo"
        ./justdo update justdo
    fi

    #
    # Set as main setup (So the machine's $ justdo command will refer to it)
    #
    announceMainStep "Set installed SDK as the main justdo setup - will make the global $(style.info)$ justdo$(style.importantInfo) command to refer to it"
    ./justdo set-current-folder-as-main-setup

    #
    # Perform installation
    #
    if [[ "$SDK_UTILS_ONLY" != "true" ]]; then
        announceMainStep "Install the JustDo SDK"
        ./justdo install essential
    fi
popd

announceMainStep "JustDo installation completed and available under the folder: $output_folder"

announceStep "JustDo is available on: http://local.justdo.com"
