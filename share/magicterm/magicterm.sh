# -*- mode: sh; sh-shell: bash -*-

: ${mt_verbose:=1}       # assign default value

DCS=$'\eP'
CSI=$'\e['
ST=$'\e\\'
OSC=$'\e]'
BEL=$'\a'                   # accepted as string terminal for OSC cmds
ESC=$'\e'

MT_ECHO () {
    (( mt_verbose )) && echo "$@" >&2
}

has_true_color () {
    [[ -v _has_true_color ]] && [[ "$_has_true_color" != "" ]] && return $_has_true_color

    local REPLY
    local SAVECOLOR

    MT_ECHO "truecolor? #1"

    echo -n "${DCS}\$qm${ST}" >/dev/tty
    read -d$'\\' -s -t 0.25 SAVECOLOR </dev/tty
    if [[ "${SAVECOLOR}" = "" ]] ; then
        _has_true_color=1
        MT_ECHO "no"
        return 1
    fi

    MT_ECHO "truecolor? #2"

    echo -n "${CSI}38;2;254;254;254m" >/dev/tty
    echo -n "${DCS}\$qm${ST}" >/dev/tty # request status string SGR
    read -d$'\\' -s -t 0.25 </dev/tty
    if [[ "${REPLY}" = *"254;254;254"* ]] || [[ "${REPLY}" = *"254:254:254"* ]]; then
        echo -n "${SAVECOLOR}" >/dev/tty
        _has_true_color=0
        MT_ECHO "yes"
        return 0
    fi

    MT_ECHO "truecolor? #3"

    echo -n "${CSI}38:2:254:254:254m" >/dev/tty
    echo -n "${DCS}\$qm${ST}" >/dev/tty # request status string SGR
    read -d$'\\' -s -t 0.25 </dev/tty
    if [[ "${REPLY}" = *"254;254;254"* ]] || [[ "${REPLY}" = *"254:254:254"* ]]; then
        echo -n "${SAVECOLOR}" >/dev/tty
        _has_true_color=0
        MT_ECHO "yes"
        return 0
    fi

    echo -n "${SAVECOLOR}" >/dev/tty
    _has_true_color=1
    MT_ECHO "no"
    return 1
}

has_256_color () {
    [[ -v _has_256_color ]] && [[ "$_has_256_color" != "" ]] && return $_has_256_color

    local REPLY

    MT_ECHO "256? #1"

    echo -n $'\e]4;255;?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "${REPLY}" != "" ]] ; then
        _has_256_color=0
        MT_ECHO "yes"
        return 0
    fi

    MT_ECHO "256? #2"

    echo -n $'\e]4:255:?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "${REPLY}" != "" ]] ; then
        _has_256_color=0
        MT_ECHO "yes"
        return 0
    fi

    _has_256_color=1
    MT_ECHO "no"
    return 1
}

has_88_color () {
    [[ -v _has_88_color ]] && [[ "$_has_88_color" != "" ]] && return $_has_88_color

    local REPLY

    MT_ECHO "88? #1"

    echo -n $'\e]4;87;?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "$REPLY" != "" ]] ; then
        _has_88_color=0
        MT_ECHO "yes"
        return 0
    fi

    MT_ECHO "88? #2"

    echo -n $'\e]4:87:?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "$REPLY" != "" ]] ; then
        _has_88_color=0
        MT_ECHO "yes"
        return 0
    fi

    _has_88_color=1
    MT_ECHO "no"
    return 1
}

has_16_color () {
    [[ -v _has_16_color ]] && [[ "$_has_16_color" != "" ]] && return $_has_16_color

    local REPLY

    MT_ECHO "16? #1"

    echo -n $'\e]4;15;?\a' >/dev/tty

    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "$REPLY" != "" ]] ; then
        _has_16_color=0
        MT_ECHO "yes"
        return 0
    fi

    MT_ECHO "16? #2"

    echo -n $'\e]4:15:?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "$REPLY" != "" ]] ; then
        _has_16_color=0
        MT_ECHO "yes"
        return 0
    fi

    _has_16_color=1
    MT_ECHO "no"
    return 1
}

set_terminfo_has () {
    if type -p infocmp >/dev/null ; then
        MT_ECHO "will use infocmp"
        terminfo_has () {
            infocmp "${1:-$TERM}" >/dev/null 2>/dev/null
        }
    elif type -p toe >/dev/null ; then
        MT_ECHO "will use toe -a"
        terminfo_has () {
            toe -a | awk '{print $1}' | grep --quiet --fixed-strings --line-regexp --regexp="${1:-$TERM}"
        }
    else
        echo "cannot detect terminal type" >&2
        return 1
    fi
}

do_magicterm () {
    local OPTARG
    local OPTIND=1
    local OPTERR=1
    local OPTION

    local mt_verbose=0
    local _has_true_color=''
    local _has_256_color=''
    local _has_88_color=''
    local _has_16_color=''

    while getopts 'vh' OPTION "${@}" ; do
        case "${OPTION}" in
            'v')
                mt_verbose=$((mt_verbose + 1));;
            'h')
                usage; exit 2;;
            *)
                exit 1;;
        esac
    done
    shift $((OPTIND - 1))

    set_terminfo_has || return 1

    # Certain local terminal programs, and other environments, can
    # short-circuit that big ole' else clause from hell below.
    if [[ -v TERM_PROGRAM ]] && [[ "${TERM_PROGRAM}" = "Apple_Terminal" ]] ; then
        TERM=xterm-256color; unset COLORTERM
    elif [[ -v TERM_PROGRAM ]] && [[ "${TERM_PROGRAM}" = "iTerm.app" ]] ; then
        TERM=xterm-256color; unset COLORTERM
    elif [[ -v TERMKIT_HOST_APP ]] && [[ "${TERMKIT_HOST_APP}" = "Cathode" ]]  ;then
        TERM=xterm-256color; unset COLORTERM
    elif [[ -v TERM_PROGRAM ]] && [[ "$TERM_PROGRAM" = "tmux" ]] ; then
        export TERM=tmux-256color; unset COLORTERM
    elif [[ -v TMUX ]] && [[ "${TMUX}" != "" ]] ; then
        export TERM=tmux-256color; unset COLORTERM
    elif [[ -v STY ]] && [[ "$STY" != "" ]] ; then
        export TERM=screen-256color; unset COLORTERM
    else
        if [[ "$TERM" = "screen-direct" ]]   ; then if terminfo_has && has_true_color ; then export COLORTERM=truecolor ; return ; else export TERM=screen-256color COLORTERM=truecolor ; fi ; fi
        if [[ "$TERM" = "screen-256color" ]] ; then if terminfo_has && has_256_color  ; then export COLORTERM=truecolor ; return ; else export TERM=xterm-direct COLORTERM=truecolor ; fi ; fi
        if [[ "$TERM" = "tmux-direct" ]]     ; then if terminfo_has && has_true_color ; then export COLORTERM=truecolor ; return ; else export TERM=tmux-256color COLORTERM=truecolor ; fi ; fi
        if [[ "$TERM" = "tmux-256color" ]]   ; then if terminfo_has && has_256_color  ; then export COLORTERM=truecolor ; return ; else export TERM=xterm-direct COLORTERM=truecolor ; fi ; fi
        if [[ "$TERM" = "mintty-direct" ]]   ; then if terminfo_has && has_true_color ; then export COLORTERM=truecolor ; return ; else export TERM=xterm-direct COLORTERM=truecolor ; fi ; fi
        if [[ "$TERM" = "xterm-direct" ]]    ; then if terminfo_has && has_true_color ; then export COLORTERM=truecolor ; return ; else export TERM=xterm-256color; unset COLORTERM  ; fi ; fi
        if [[ "$TERM" = "screen-256color" ]] ; then if terminfo_has && has_256_color  ; then unset COLORTERM            ; return ; else export TERM=xterm-256color; unset COLORTERM  ; fi ; fi
        if [[ "$TERM" = "xterm-256color" ]]  ; then if terminfo_has && has_256_color  ; then unset COLORTERM            ; return ; else export TERM=xterm-88color; unset COLORTERM   ; fi ; fi
        if [[ "$TERM" = "xterm-88color" ]]   ; then if terminfo_has && has_88_color   ; then unset COLORTERM            ; return ; else export TERM=xterm; unset COLORTERM           ; fi ; fi
    fi
}
