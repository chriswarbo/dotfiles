{ attrsToDirs', bash, fetchFromGitHub, fetchurl, gcc, openjdk8, python3,
  runCommand, unpack', wrap }:

with rec {
  prebuilt = unpack' "async-profiler-macos" (fetchurl {
    sha256 = "15dj5gs005fna0jiz6g9n261ffcqxm7jifww01lb834qwjdqkm3q";
    url    = "https://github.com/jvm-profiling-tools/async-profiler" +
             "/releases/download/v2.0-rc/" +
             "async-profiler-2.0-rc-macos-x64.tar.gz";
  });

  build = runCommand "async-profiler-build"
    {
      inherit source;
      buildInputs = [ gcc ];
      JAVA_HOME   = openjdk8;
    }
    ''
      cp -r "$source" ./source
      chmod +w -R ./source
      cd ./source
      sed -e 's@#include "log.h"@#include "log.h"\n#include <cstring>@g' \
          -i src/symbols_macos.cpp
      make

      mkdir "$out"
      mv build "$out"/
    '';

  source = fetchFromGitHub {
    owner  = "jvm-profiling-tools";
    repo   = "async-profiler";
    rev    = "b807987";
    sha256 = "1m64fvv7436i159hgx9ycgmmxdk8x3ir8pqb4ywdyy5jf5g3c5ra";
  };
};
attrsToDirs' "async-profiler" {
  bin = rec {
    async-profiler = wrap {
      name = "async-profiler";
      vars = { SCRIPT_DIR = prebuilt; };
      file = runCommand "profiler.sh-patched"
        {
          source = prebuilt;
        }
        ''
          sed -e 's@^SCRIPT_DIR=.*@@g' < "$source/profiler.sh" > "$out"
          chmod +x "$out"
        '';
    };

    jvm-profiler = wrap {
      name   = "profile-jvm-command";
      paths  = [ bash ];
      vars   = { profiler = async-profiler; };
      script = ''
        #!/usr/bin/env bash
        set -e

        if [[ -z "$FLAMEGRAPH" ]]
        then
          I=0
          while FLAMEGRAPH="$PWD/flamegraph-$I.html" && [[ -e "$FLAMEGRAPH" ]]
          do
            I=$(( I + 1 ))
          done
        fi
        echo "Outputting to $FLAMEGRAPH" 1>&2

        "$profiler" -f "$FLAMEGRAPH" "$@"
      '';
    };

    profile-jvm-command = wrap {
      name  = "profile-jvm-command";
      file  = ./profile-jvm-command.py;
      paths = [ (python3.withPackages (p: [ p.psutil ])) ];
      vars  = { JVM_PROFILER = jvm-profiler; };
    };
  };
}
