{ runCommand, sources ? import ./nix/sources.nix }:
with { inherit (sources) cliclick; };
runCommand "cliclick-${cliclick.version}" {} ''
  D=""
  for V in "${cliclick}"/*
  do
    [[ -z "$D" ]] || {
      echo "Found multiple entries in source ${cliclick}, aborting" 1>&2
      exit 1
    }
    D="$V"
  done
  ln -s "$D" "$out"
''
