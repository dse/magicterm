# -*- mode: sh; sh-shell: bash; comment-column: 56; fill-column: 79 -*-

DCS=$'\eP'
CSI=$'\e['
ST=$'\e\\'
OSC=$'\e]'
BEL=$'\a'                                               # terminate OSC cmds only
ESC=$'\e'

has_true_color () {
    [[ -v _has_true_color ]] && [[ "$_has_true_color" != "" ]] && return $_has_true_color
    local REPLY
    echo -n "${CSI}38;2;254;254;254m" >/dev/tty         # set fg color
    echo -n "${DCS}\$qm${ST}" >/dev/tty                 # request fg color
    read -d$'\\' -s -t 0.25 </dev/tty
    if [[ "${REPLY}" = *"254;254;254"* ]] || [[ "${REPLY}" = *"254:254:254"* ]]; then
        echo -n "${CSI}m" >/dev/tty                     # reset fg color
        _has_true_color=0; return 0
    fi
    echo -n "${CSI}38:2:254:254:254m" >/dev/tty         # set fg color
    echo -n "${DCS}\$qm${ST}" >/dev/tty                 # request fg color
    read -d$'\\' -s -t 0.25 </dev/tty
    if [[ "${REPLY}" = *"254;254;254"* ]] || [[ "${REPLY}" = *"254:254:254"* ]]; then
        echo -n "${CSI}m" >/dev/tty                     # reset fg color
        _has_true_color=0; return 0
    fi
    echo -n "${CSI}m" >/dev/tty                         # reset fg color
    _has_true_color=1; return 1
}

has_256_color () {
    [[ -v _has_256_color ]] && [[ "$_has_256_color" != "" ]] && return $_has_256_color
    local REPLY
    echo -n $'\e]4;255;?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "${REPLY}" != "" ]] ; then
        _has_256_color=0; return 0
    fi
    echo -n $'\e]4:255:?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "${REPLY}" != "" ]] ; then
        _has_256_color=0; return 0
    fi
    _has_256_color=1; return 1
}

has_88_color () {
    [[ -v _has_88_color ]] && [[ "$_has_88_color" != "" ]] && return $_has_88_color
    local REPLY
    echo -n $'\e]4;87;?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "$REPLY" != "" ]] ; then
        _has_88_color=0; return 0
    fi
    echo -n $'\e]4:87:?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "$REPLY" != "" ]] ; then
        _has_88_color=0; return 0
    fi
    _has_88_color=1; return 1
}

has_16_color () {
    [[ -v _has_16_color ]] && [[ "$_has_16_color" != "" ]] && return $_has_16_color
    local REPLY
    echo -n $'\e]4;15;?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "$REPLY" != "" ]] ; then
        _has_16_color=0; return 0
    fi
    echo -n $'\e]4:15:?\a' >/dev/tty
    read -d$'\a' -s -t 0.25 </dev/tty
    if [[ "$REPLY" != "" ]] ; then
        _has_16_color=0; return 0
    fi
    _has_16_color=1; return 1
}

set_terminfo_detector () {
    if type -p infocmp >/dev/null ; then
        (( mt_verbose )) && echo "will use infocmp" >&2
        terminfo_has () {
            infocmp "${1:-$TERM}" >/dev/null 2>/dev/null
        }
    elif type -p toe >/dev/null ; then
        (( mt_verbose )) && echo "will use toe -a" >&2
        terminfo_has () {
            toe -a | awk '{print $1}' | grep --quiet --fixed-strings --line-regexp --regexp="${1:-$TERM}"
        }
    else
        echo "cannot detect terminal type" >&2
        return 1
    fi
}

do_magicterm () {
    set_terminfo_detector || return 1

    # If your terminal emulator sets COLORTERM, make sure TERM is something
    # that supports truecolor and is in terminfo.
    #
    # TODO --- I mean, can we assume that the terminal emulator is setting TERM
    # to something that will work too?
    if [[ -v COLORTERM ]] && [[ "${COLORTERM}" != "" ]] ; then
        >&2 echo "TERM=${TERM}; COLORTERM=${COLORTERM}"
        case "${TERM}" in
            xterm-direct)
                if terminfo_has "${TERM}" ; then
                    return 0
                fi
                ;;
            *-direct)
                if terminfo_has "${TERM}" ; then
                    return 0
                fi
                if terminfo_has xterm-direct ; then
                    export TERM=xterm-direct
                    return 0
                fi
                ;;
            xterm|xterm-*)
                if terminfo_has xterm-direct ; then
                    export TERM=xterm-direct
                    return 0
                fi
                ;;
            *-256color)
                local newterm="${TERM%-256color}-direct"
                if terminfo_has "${newterm}" ; then
                    export TERM="${newterm}"
                    return 0
                fi
                if terminfo_has xterm-direct ; then
                    export TERM=xterm-direct
                    return 0
                fi
                ;;
            *-88color)
                local newterm="${TERM%-88color}-direct"
                if terminfo_has "${newterm}" ; then
                    export TERM="${newterm}"
                    return 0
                fi
                if terminfo_has xterm-direct ; then
                    export TERM=xterm-direct
                    return 0
                fi
                ;;
            screen|mintty|tmux)
                local newterm="${TERM}-direct"
                if terminfo_has "${newterm}" ; then
                    export TERM="${newterm}"
                    return 0
                fi
                if terminfo_has xterm-direct ; then
                    export TERM=xterm-direct
                    return 0
                fi
                ;;
        esac
    fi

    local mt_verbose=0
    local _has_true_color=''
    local _has_256_color=''
    local _has_88_color=''
    local _has_16_color=''
    local mt_short_circuit=1

    local OPTARG
    local OPTIND=1
    local OPTERR=1
    local OPTION

    while getopts 'vhf' OPTION "${@}" ; do
        case "${OPTION}" in
            'v')
                mt_verbose=$((mt_verbose + 1));;
            'h')
                usage; exit 2;;
            'f')
                mt_short_circuit=0;;
            *)
                exit 1;;
        esac
    done
    shift $((OPTIND - 1))

    if (( mt_short_circuit )) ; then
        if [[ -v TERM_PROGRAM ]] && [[ "${TERM_PROGRAM}" = "Apple_Terminal" ]] ; then
            TERM=xterm-256color; unset COLORTERM
            return 0
        elif [[ -v TERM_PROGRAM ]] && [[ "${TERM_PROGRAM}" = "iTerm.app" ]] ; then
            TERM=xterm-256color; unset COLORTERM
            return 0
        elif [[ -v TERMKIT_HOST_APP ]] && [[ "${TERMKIT_HOST_APP}" = "Cathode" ]] ; then
            TERM=xterm-256color; unset COLORTERM
            return 0
        elif [[ -v TERM_PROGRAM ]] && [[ "$TERM_PROGRAM" = "tmux" ]] ; then
            export TERM=tmux-256color; unset COLORTERM
            return 0
        elif [[ -v TMUX ]] && [[ "${TMUX}" != "" ]] ; then
            export TERM=tmux-256color; unset COLORTERM
            return 0
        elif [[ -v STY ]] && [[ "$STY" != "" ]] ; then
            export TERM=screen-256color; unset COLORTERM
            return 0
        elif [[ -v GNOME_TERMINAL_SCREEN ]] || [[ -v GNOME_TERMINAL_SERVICE ]] ; then
            if terminfo_has xterm-direct && has_true_color ; then
                export TERM=xterm-direct COLORTERM=truecolor
                return 0
            fi
            export TERM=xterm-256color; unset COLORTERM
            return 0
        fi
    fi

    if [[ "$TERM" = "screen-direct" ]]   ; then if terminfo_has && has_true_color ; then export COLORTERM=truecolor ; return ; else export TERM=screen-256color COLORTERM=truecolor ; fi ; fi
    if [[ "$TERM" = "screen-256color" ]] ; then if terminfo_has && has_256_color  ; then export COLORTERM=truecolor ; return ; else export TERM=xterm-direct COLORTERM=truecolor    ; fi ; fi
    if [[ "$TERM" = "tmux-direct" ]]     ; then if terminfo_has && has_true_color ; then export COLORTERM=truecolor ; return ; else export TERM=tmux-256color COLORTERM=truecolor   ; fi ; fi
    if [[ "$TERM" = "tmux-256color" ]]   ; then if terminfo_has && has_256_color  ; then export COLORTERM=truecolor ; return ; else export TERM=xterm-direct COLORTERM=truecolor    ; fi ; fi
    if [[ "$TERM" = "mintty-direct" ]]   ; then if terminfo_has && has_true_color ; then export COLORTERM=truecolor ; return ; else export TERM=xterm-direct COLORTERM=truecolor    ; fi ; fi
    if [[ "$TERM" = "xterm-direct" ]]    ; then if terminfo_has && has_true_color ; then export COLORTERM=truecolor ; return ; else export TERM=xterm-256color; unset COLORTERM     ; fi ; fi
    if [[ "$TERM" = "screen-256color" ]] ; then if terminfo_has && has_256_color  ; then unset COLORTERM            ; return ; else export TERM=xterm-256color; unset COLORTERM     ; fi ; fi
    if [[ "$TERM" = "xterm-256color" ]]  ; then if terminfo_has && has_256_color  ; then unset COLORTERM            ; return ; else export TERM=xterm-88color; unset COLORTERM      ; fi ; fi
    if [[ "$TERM" = "xterm-88color" ]]   ; then if terminfo_has && has_88_color   ; then unset COLORTERM            ; return ; else export TERM=xterm; unset COLORTERM              ; fi ; fi
}
