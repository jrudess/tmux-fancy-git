#!/usr/bin/env bash

PANE_PATH=$(tmux display-message -p -F "#{pane_current_path}")
cd $PANE_PATH

# Navigate out of the .git/ area to avoid some kinds of git errors
if pwd | grep -q "\\.git"; then
    cd "$(pwd | sed -E 's/\.git(\/.*)?//g')" || exit
fi

NAME=""
DIFF=""
AHEAD=""
BEHIND=""
STASHES=""
PORCELAIN="?"
LOCAL_BRANCHES=""

check_error() {
    RET_CODE="$1"
    CODE="$2"
    if [ "$RET_CODE" != 0 ]; then
        echo "ERROR $CODE:$RET_CODE"
        exit 1
    fi
}

git_bg_fetch() {
    if [[ -n $(git remote show) ]]; then
        local repo=$(git rev-parse --show-toplevel 2> /dev/null)
        local fetch_head="$repo/.git/FETCH_HEAD"

        # Don't start a new fetch if already fetching
        if [[ -e "$fetch_head" ]]; then
            local old_head=$(find "$fetch_head" 2> /dev/null)

            if [[ -n "$old_head" ]]; then
                git fetch --quiet &> /dev/null
            fi
        fi
    fi
}

git_diffstat() {
    if [[ -n $NAME ]]; then
        local diff=$(git diff | diffstat -f0 -mvs)

        error=$(check_error "$?" "3")

        if [ "$error" == "" ]; then
            local insertions=$(echo $diff | sed -rn 's/^.*, ([0-9]*) insertion.*/\1/p')
            local modifications=$(echo $diff | sed -rn 's/^.*, ([0-9]*) modification.*/\1/p')
            local deletions=$(echo $diff | sed -rn 's/^.*, ([0-9]*) deletion.*/\1/p')

            local insertions=$([ -n "$insertions" ] && echo "+$insertions" || echo "+0")
            local modifications=$([ -n "$modifications" ] && echo "~$modifications" || echo "~0")
            local deletions=$([ -n "$deletions" ] && echo "-$deletions" || echo "-0")

            echo "$insertions $modifications $deletions"
        fi
    fi
}

git_fetch() {
    local info=$(git status --untracked-files=normal --porcelain)

    error=$(check_error "$?" "1")

    PORCELAIN="$info"

    if [ "$error" == "" ]; then
         AHEAD=$(grep 'ahead'  <<< "$info" | sed -E  's/.*ahead[[:space:]]+([0-9]+).*/\1/g')
        BEHIND=$(grep 'behind' <<< "$info" | sed -E 's/.*behind[[:space:]]+([0-9]+).*/\1/g')
        error=$(check_error "$?" "2")

        if [ "$error" == "" ]; then
            STASHES=$(git stash list | wc -l)
            LOCAL_BRANCHES=$(git branch -vv | cut -c 3- | awk '$3 !~/\[origin/ { print $1 }' | wc -l)
            NAME="$(git rev-parse --abbrev-ref HEAD)"
            DIFF="$(git_diffstat)"
        fi
    fi

    git_bg_fetch &
}

git_print() {
    local src_ctrl="$DIFF "
    local staged=""
    local tree_deleted=""
    local index_deleted=""
    local unstaged=""
    local untracked=""
    local conflicts=""

    if [ "$error" == "" ]; then
        if [ "$PORCELAIN" != "?" ]; then
            local staged=0
            local index_added=0
            local index_deleted=0
            local tree_deleted=0
            local unstaged=0
            local untracked=0
            local conflicts=0
            local unknown=0

            local IFS=$'\n'
            for line in $PORCELAIN; do
                if   [[ $line =~ ^##          ]]; then true
                elif [[ $line =~ ^[MRC][\ MD] ]]; then ((staged        ++))
                elif [[ $line =~ ^A[\ MD]     ]]; then ((index_added   ++))
                elif [[ $line =~ ^D\          ]]; then ((index_deleted ++))
                elif [[ $line =~ ^[\ MARC]D   ]]; then ((tree_deleted  ++))
                elif [[ $line =~ ^[\ MARC]M   ]]; then ((unstaged      ++))
                elif [[ $line =~ ^\?\?        ]]; then ((untracked     ++))
                elif [[ $line =~ ^(DD|AU|UD|UA|DU|AA|UU) ]]; then
                    # DD  unmerged, both deleted
                    # AU  unmerged, added by us
                    # UD  unmerged, deleted by them
                    # UA  unmerged, added by them
                    # DU  unmerged, deleted by us
                    # AA  unmerged, both added
                    # UU  unmerged, both modified
                    ((conflicts++))
                else
                    ((unknown++))
                fi
            done
        fi

        build_section() {
            local colour=$1
            local symbol=$2
            local value=$3
            if { [[ $value ]] && [[ $value != 0 ]]; }; then
                echo "$colour$symbol$value"
            fi
        }

        src_ctrl+=$(build_section ""         "" " $NAME"         )
        src_ctrl+=" ["
        src_ctrl+=$(build_section "$white"   '↑' "$AHEAD"         )
        src_ctrl+=$(build_section "$white"   '↓' "$BEHIND"        )
        src_ctrl+=$(build_section "$green"   '●' "$staged"        )
        src_ctrl+=$(build_section "$green"   '+' "$index_added"   )
        src_ctrl+=$(build_section "$green"   '-' "$index_deleted" )
        src_ctrl+=$(build_section "$red"     '✖' "$conflicts"     )
        src_ctrl+=$(build_section "$red"     '+' "$unstaged"      )
        src_ctrl+=$(build_section "$red"     '-' "$tree_deleted"  )
        src_ctrl+=$(build_section "$magenta" '…' "$untracked"     )
        src_ctrl+=$(build_section "$yellow"  '⚑' "$STASHES"       )
        src_ctrl+=$(build_section "$yellow"  '!' "$LOCAL_BRANCHES")
        src_ctrl+=$(build_section "$magenta" '?' "$unknown"       )
        src_ctrl+="]"
    else
        src_ctrl+="$red$error"
    fi

    printf " %s" "$src_ctrl"
}

main() {
  git_fetch
  git_print
}

main
