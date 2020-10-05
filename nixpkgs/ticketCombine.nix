# A command for combining train ticket PDFs into one document, with
# two per page
{ mkBin, texlive }:

mkBin {
  name  = "ticketCombine";
  paths = [
    (texlive.combine { inherit (texlive) pdfjam scheme-small; })
  ];
  script = ''
    #!/usr/bin/env bash
    set -e

    function go {
      F=combined
      N=1
      while [[ -e "$F $N.pdf" ]]
      do
        N=$(( N + 1 ))
      done
      pdfjam "$1" "$2" --nup 2x1 --outfile "$F $N.pdf"
    }

    N=$#
    if [[ $(( N % 2 )) -gt 0 ]]
    then
      echo "Need even number of args (got $N), to combine two per page" 1>&2
      exit 1
    fi

    while [[ "$#" -gt 1 ]]
    do
      go "$1" "$2"
      shift; shift
    done
  '';
}
