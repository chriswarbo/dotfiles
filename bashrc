#!/usr/bin/env bash

export PATH="/run/current-system/sw/bin:$HOME/repos/dotfiles/nixpkgs/result/bin:$HOME/.nix-profile/bin:$PATH"

# See https://direnv.net/docs/hook.html
eval "$(direnv hook bash)"

pushd "$(dirname "$(readlink -f "$HOME/.bashrc")")/nixpkgs" > /dev/null
  export NIX_PATH=$(./nixPath.sh)
popd > /dev/null

showTime() {
    if [[ "$?" -eq 0 ]]
    then
        TIMECOLOR='\e[92m'
    else
        TIMECOLOR='\e[91m'
    fi
    echo -e "$TIMECOLOR$(date '+%s')\e[0m"
}

me() {
    FULLHOST=$(hostname)
    [[ "x$FULLHOST" = 'xMacBook-Pro.local' ]] && FULLHOST='mac'
    echo -e "\e[93m$USER@$FULLHOST\e[0m"
}

whereami(){
    echo -e "\e[96m$PWD\e[0m"
}

PS1='$(showTime) $(me) $(whereami) $ '
