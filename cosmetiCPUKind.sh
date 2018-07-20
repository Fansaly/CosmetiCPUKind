#!/bin/bash

function help() {
    echo
    echo "    -u    Customization CPU Kind."
    echo "    -r    Reset AppleSystemInfo.strings."
    echo "    -h    This message."
    echo
    echo "    usage: ./$(basename $0) [-r] | [-u <Processor>]"
    echo
}

function getLProj() {
    AppleSystemInfoRes=$@
    exstr=.lproj
    regex=\\${exstr}

    langList=$(ls -l "${AppleSystemInfoRes}" | grep -e ".*${regex}$" | awk '{print $9}' | perl -pe 's/'"${regex}"'//')
    langPref=$(osascript -e 'user locale of (get system info)' | perl -pe 's/[_-].*$//')
    langOpt=$(printf "${langList}" | grep -i -e "^${langPref}.*")
    # langOpt=$(printf "${langList}" | grep -i -e "^e.*")
    if [[ ! -n ${langOpt} ]]; then langOpt=${langList}; fi
    langOpt=(${langOpt})
    lang=${langOpt}
    idx=0

    if [[ ${#langOpt[@]} -gt 1 ]]; then
        echo -e "\033[0;37mMultiple languages detected\033[0m"
        echo -e "\033[0;37mSelect OS current lang, plz\033[0m"
        echo -e "\033[0;37m---------------------------\033[0m"

        for i in ${!langOpt[@]}; do
            echo -e "  \033[0;96m$((${i} + 1))\033[0m\033[0;37m:\033[0m ${langOpt[${i}]}"
        done

        echo -e "\033[0;37m---------------------------\033[0m"

        while :; do
            # read -n1 -p "Select (1 by Enter): " confirm
            read -p "Select (1 by Enter): " confirm

            [ -z "${confirm}" ] && confirm=1

            if [[ ${confirm} == [1-${#langOpt[@]}] ]]; then
                idx=$((${confirm} - 1))
                break
            fi
        done
    fi

    lang=${langOpt[${idx}]}
    # echo "Selectd:" ${lang}" (index:${idx})"

    if [ -z ${lProj+x} ]; then
        echo "${lang}${exstr} <inside>"
    else
        lProj=${lang}${exstr}
    fi
}

function getCPUKind() {
    PROCESSOR=$@

    PROCESSOR=$(printf "${PROCESSOR}" | perl -pe 's/\s+cpu//i')
    PROCESSOR=$(printf "${PROCESSOR}" | perl -pe 's/\(R\)//g and s/\(TM\)//ig')

    CPUKind=$(printf "${PROCESSOR}" | perl -pe 's/\s+@.*//')

    echo "${CPUKind}"
}

# p="
# Intel(R) Xeon(R) CPU E5-1650 v2 @ 3.5GHz
# Intel(R) Core(TM) i7-4770K CPU @ 3.50GHz
# Intel(R) Core(TM)2 Duo CPU P8600 @ 2.40GHz
# Intel(R) Core(TM)2 CPU 6700 @ 2.66GHz
# Intel(R) Atom(TM) CPU N270 @ 1.60GHz
# Genuine Intel(R) CPU T2500 @ 2.00GHz
# AMD Ryzen 7 1700X
# "
# export -f getCPUKind
# printf "${p}" | grep -e "[^\s]" | perl -pe 's/\(/\\(/g and s/\)/\\)/g' | awk '{ system("getCPUKind " $0) }'

while getopts u:d:rh opt; do
    case $opt in
        u)
            CPUKind=$OPTARG
        ;;
        r)
            reset=1
        ;;
        h)
            help
            exit 0
        ;;
    esac
done


AppleSystemInfoRes=/System/Library/PrivateFrameworks/AppleSystemInfo.framework/Versions/A/Resources
AppleSystemInfo=AppleSystemInfo.strings
lProj= && getLProj ${AppleSystemInfoRes}

FILE=${AppleSystemInfoRes}/${lProj}/${AppleSystemInfo}
srcFile=${FILE}.bak
outFile=/var/tmp/${AppleSystemInfo}


# reset
if [[ ${reset} ]]; then
    if [[ -f "${srcFile}" ]]; then
        rm "${FILE}"
        mv "${srcFile}" "${FILE}"
    fi
    exit 0
fi


if [[ ! -f "${srcFile}" ]]; then cp "${FILE}" "${srcFile}"; fi

if [[ ! -n ${CPUKind} ]]; then
    CPUKind=$(getCPUKind $(sysctl -n machdep.cpu.brand_string))
fi

# set cosmetic CPUKind
cp "${srcFile}" "${outFile}"
plutil -replace UnknownCPUKind -string "${CPUKind}" "${outFile}"

# apply cosmetic CPUKind
codesign -f -s - "${outFile}"
cp "${outFile}" "${FILE}"
rm "${outFile}"
