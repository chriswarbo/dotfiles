{ config, pkgs, ... }:

with builtins // { sources = import ./nix/sources.nix; };
{
  /* Avoids the following error, which appeared when upgrading to nixpkgs 20.09:
  while evaluating 'evalModules' at
    /nix/store/...-nixpkgs-src/lib/modules.nix:21:17, called from
    /nix/store/...-nix-darwin-src/modules/documentation/default.nix:19:24:
    The option `nixpkgs.localSystem' defined in `<unknown-file>' does not exist.
  */
  documentation.enable = false;

  environment = {
    darwinConfig = toString <home/.nixpkgs/darwin-configuration.nix>;

    # Files to create in /etc. Things to note:
    #  - Attribute names should be the full path to the file (relative to /etc),
    #    e.g. "ssh/ssh_config" rather than nested attrsets like ssh.ssh_config
    #  - Existing files created outside Nix will not be overwritten (a warning
    #    will be given by 'darwin-rebuild switch'). If this happens, it's
    #    usually useful to copy/paste the existing content into here, along with
    #    a comment indicating where it's come from
    #  - When we comment these files, it's better to put the comments in the
    #    content (if that file's format supports comments). That way it's easier
    #    to figure out what's going on when reading the generated file itself.
    etc = {
      "DefaultKeyBinding.dict".text = ''
        {
          "~f"    = "moveWordForward:";
          "~b"    = "moveWordBackward:";
          "~d"    = "deleteWordForward:";
          "~^h"   = "deleteWordBackward:";
          "~\010" = "deleteWordBackward:";    /* Option-backspace */
          "~\177" = "deleteWordBackward:";    /* Option-delete */
          "~v"    = "pageUp:";
          "^v"    = "pageDown:";
          "~<"    = "moveToBeginningOfDocument:";
          "~>"    = "moveToEndOfDocument:";
          "^/"    = "undo:";
          "~/"    = "complete:";
          "^g"    = "_cancelKey:";
          "^a"    = "moveToBeginningOfLine:";
          "^e"    = "moveToEndOfLine:";
          "~c"    = "capitalizeWord:"; /* M-c */
          "~u"    = "uppercaseWord:";  /* M-u */
          "~l"    = "lowercaseWord:";  /* M-l */
          "^t"    = "transpose:";      /* C-t */
          "~t"    = "transposeWords:"; /* M-t */

          /* Ctrl shortcuts */
          "^l"        = "centerSelectionInVisibleArea:";  /* C-l          Recenter */
          "^/"        = "undo:";                          /* C-/          Undo */
          "^_"        = "undo:";                          /* C-_          Undo */
          "^ "        = "setMark:";                       /* C-Spc        Set mark */
          "^\@"       = "setMark:";                       /* C-@          Set mark */
          "^w"        = "deleteToMark:";                  /* C-w          Delete to mark */
          /* Meta shortcuts */
          "~f"        = "moveWordForward:";               /* M-f          Move forward word */
          "~b"        = "moveWordBackward:";              /* M-b          Move backward word */
          "~<"        = "moveToBeginningOfDocument:";     /* M-<          Move to beginning of document */
          "~>"        = "moveToEndOfDocument:";           /* M->          Move to end of document */
          "~v"        = "pageUp:";                        /* M-v          Page Up */
          "~/"        = "complete:";                      /* M-/          Complete */
          "~c"        = ( "capitalizeWord:",              /* M-c          Capitalize */
                          "moveForward:",
                          "moveForward:");
          "~u"        = ( "uppercaseWord:",               /* M-u          Uppercase */
                          "moveForward:",
                          "moveForward:");
          "~l"        = ( "lowercaseWord:",               /* M-l          Lowercase */
                          "moveForward:",
                          "moveForward:");
          "~d"        = "deleteWordForward:";             /* M-d          Delete word forward */
          "^~h"       = "deleteWordBackward:";            /* M-C-h        Delete word backward */
          "~\U007F"   = "deleteWordBackward:";            /* M-Bksp       Delete word backward */
          "~t"        = "transposeWords:";                /* M-t          Transpose words */
          "~\@"       = ( "setMark:",                     /* M-@          Mark word */
                          "moveWordForward:",
                          "swapWithMark");
          "~h"        = ( "setMark:",                     /* M-h          Mark paragraph */
                          "moveToEndOfParagraph:",
                          "swapWithMark");
          /* C-x shortcuts */
          "^x" = {
              "u"     = "undo:";                          /* C-x u        Undo */
              "k"     = "performClose:";                  /* C-x k        Close */
              "^f"    = "openDocument:";                  /* C-x C-f      Open (find file) */
              "^x"    = "swapWithMark:";                  /* C-x C-x      Swap with mark */
              "^m"    = "selectToMark:";                  /* C-x C-m      Select to mark*/
              "^s"    = "saveDocument:";                  /* C-x C-s      Save */
              "^w"    = "saveDocumentAs:";                /* C-x C-w      Save as */
          };
          }
        }
      '';

      hosts.text = ''
        ##
        # Host Database
        #
        # localhost is used to configure the loopback interface
        # when the system is booting.  Do not change this entry.
        ##
        127.0.0.1	localhost
        255.255.255.255	broadcasthost
        ::1             localhost

        # The above was copy/pasted from the (default?) macOS /etc/hosts
        # The below is our own stuff
        192.168.86.32 phone

        3.9.24.243 dev-bastion
        18.132.183.139 prod-bastion
      '';

      "karabiner/karabiner.json".text = toJSON (import ./karabiner.nix {
        inherit (pkgs) lib shortcuts;
      });

      # macOS uses /etc/paths to set the PATH env var in many situations (e.g.
      # in graphical Emacs instances). We want Nix paths to appear first, not be
      # appended at the end. This is especially annoying since macOS comes with
      # lots of dummy commands like 'git' and 'python3' which just show an
      # obnoxious popup, short-circuiting their lookup in later directories. The
      # read-only filesystem prevents us from deleting them too. Grrr...
      paths.text = ''
        /Users/chris/.nix-profile/bin
        /nix/var/nix/profiles/default/bin
        /Users/chris/.nix-profile/bin
        /run/current-system/sw/bin
        /nix/var/nix/profiles/default/bin
        /usr/local/bin
        /usr/bin
        /bin
        /usr/sbin
        /sbin
      '';

      "sbt/sbtopts".text = ''
        -Dsbt.supershell=false
      '';

      shells.text = ''
        # List of acceptable shells for chpass(1).
        # Ftpd will not allow users to connect who are not using
        # one of these shells.

        /bin/bash
        /bin/csh
        /bin/dash
        /bin/ksh
        /bin/sh
        /bin/tcsh
        /bin/zsh

        /run/current-system/sw/bin/bash
        /run/current-system/sw/bin/unwrappedShell
      '';
    };

    # Make sure shared data is available, e.g. site-lisp for Emacs
    pathsToLink = [ "/share" ];

    # Packages to install globally (i.e. those which should be available to any
    # shell).
    # To see a list of package names to put here, try running:
    #     nix-env -qaP | grep wget
    # Note that we prefer to bundle things together into "metapackages", so we
    # don't need to maintain long lists of things on different machines.
    systemPackages = map (n: getAttr n pkgs) [
      "artemis-tools"
      #"async-profiler"
      "cmus"
      "devGui"
      "direnv"  # Needed by lorri
      "docGui"
      "docker"  # Do we actually need this command in the global env?
      "gnumeric"
      "htop"    # Better than macOS top
      "lftp"    # For FTP
      "lorri"   # Needed by lorri launchd service defined below
      "netCli"
    ] ++
    # Fixes, overrides, etc.
    [
      (pkgs.allowCollisions pkgs.devCli)  # binutils and gcc both provide bin/ld
      (pkgs.allowCollisions pkgs.docCli)  # Allow fonts to conflict

      pkgs.dbeaver
      (pkgs.callPackage ./displayplacer.nix { inherit sources; })
      (pkgs.callPackage ./ticketCombine.nix {})

      pkgs.aws-helpers.combined
      pkgs.aws-lambda-rie
      (pkgs.allowCollisions pkgs.cliclick)
      pkgs.loop
      pkgs.shortcuts.package  # Commands used by our keyboard shortcuts
      pkgs.wrappedShell
    ] ++

    # GUI macOS applications
    (with { inherit (pkgs) installApplication; }; [
      (installApplication rec {
        inherit (sources.dockerDesktop) version;
        name        = "DockerDesktop";
        sourceRoot  = "Docker.app";
        src         = sources.dockerDesktop.outPath;
        description = ''Includes Docker client commands and daemon'';
        homepage    = https://www.docker.com/products/docker-desktop;
      })

      (installApplication rec {
        inherit (sources.firefox) version;
        name        = "Firefox";
        sourceRoot  = "Firefox.app";
        src         = sources.firefox.outPath;
        description = "Firefox browser";
        homepage    = https://www.getfirefox.com;
      })

      (installApplication rec {
        name        = "iTerm2";
        version     = replaceStrings ["_"] ["."] sources.iterm2.version;
        sourceRoot  = "iTerm.app";
        src         = sources.iterm2.outPath;
        description = "Terminal emulator";
        homepage    = https://iterm2.com;
      })

      (installApplication rec {
        inherit (sources.postman) version;
        name        = "Postman";
        sourceRoot  = "Postman.app";
        src         = sources.postman.outPath;
        description = "GUI for testing HTTP requests and responses";
        homepage    = https://www.getpostman.com;
      })

      (installApplication rec {
        inherit (sources.slack) version;
        name        = "Slack";
        sourceRoot  = "Slack.app";
        src         = sources.slack.outPath;
        description = "Desktop client for Slack messenger";
        homepage    = https://www.slack.com;
      })

      (installApplication rec {
        inherit (sources.vncviewer) version;
        name        = "VNCViewer";
        sourceRoot  = "VNC Viewer.app";
        src         = sources.vncviewer.outPath;
        description = "RealVNC client";
        homepage    = https://www.realvnc.com;
      })
    ]) ++

    # Android apps
    [
      /*(pkgs.androidApp {
        name    = "trainline";
        package = "com.thetrainline";
        app     = pkgs.apkpure {
          name   = "trainline";
          sha256 = "1j689zwla7l0ki9r4pkvhxf61z611zs2gqkfci0lqj57b37bv9vg";
          path   =
            "trainline-buy-cheap-european-train-bus-tickets/com.thetrainline";
        };
      })*/
    ];

    variables = {
      # toString preserves paths, rather than adding them to the Nix store
      MANPATH = map toString [
        #<home/.nix-profile/share/man>
        #<home/.nix-profile/man>
        "${config.system.path}/share/man"
        "${config.system.path}/man"
        /usr/local/share/man
        /usr/share/man
        /Developer/usr/share/man
        /usr/X11/man
      ];

      EDITOR       = "emacsclient -c";
      LC_CTYPE     = "en_GB.UTF-8";
      LESSCHARSET  = "utf-8";
      LEDGER_COLOR = "true";
      PAGER        = "less";
      TERM         = "xterm-256color";
    };
  };

  fonts = {
    enableFontDir = true;
    fonts         =
      with pkgs;
      with {
        without = orig: paths: runCommand "${orig.name}-trimmed"
          { inherit orig; }
          ''
            cp -rs "$orig" "$out"
            chmod +w -R "$out"
            cd "$out"
            echo "Removing specified paths from $PWD" 1>&2
            ${concatStringsSep "\n"
                (map (f: "rm -rv " + lib.escapeShellArg f) paths)}
          '';
      };
      map pkgs.allowCollisions [
        ankacoder
        ankacoder-condensed
        anonymousPro
        camingo-code
        cascadia-code
        d2coding
        dejavu_fonts
        (without droid-fonts [
          "share/fonts/truetype/Roboto-Bold.ttf"
          "share/fonts/truetype/Roboto-BoldItalic.ttf"
          "share/fonts/truetype/Roboto-Italic.ttf"
          "share/fonts/truetype/Roboto-Light.ttf"
          "share/fonts/truetype/Roboto-LightItalic.ttf"
          "share/fonts/truetype/Roboto-Regular.ttf"
          "share/fonts/truetype/Roboto-Thin.ttf"
          "share/fonts/truetype/Roboto-ThinItalic.ttf"
          "share/fonts/truetype/RobotoCondensed-Bold.ttf"
          "share/fonts/truetype/RobotoCondensed-BoldItalic.ttf"
          "share/fonts/truetype/RobotoCondensed-Italic.ttf"
          "share/fonts/truetype/RobotoCondensed-Regular.ttf"
        ])
        (without envypn-font [
          "share/fonts/misc/fonts.dir"
        ])
        fantasque-sans-mono
        (without fira [
          "share/fonts/opentype/FiraMono-Bold.otf"
          "share/fonts/opentype/FiraMono-Medium.otf"
          "share/fonts/opentype/FiraMono-Regular.otf"
        ])
        fira-code
        fira-code-symbols
        fira-mono
        freefont_ttf
        (without google-fonts [
          "share/fonts/truetype/OxygenMono-Regular.ttf"
        ])
        gyre-fonts
        hack-font
        hasklig
        hyperscrypt-font
        liberation_ttf
        noto-fonts-emoji
        oxygenfonts
        source-code-pro
        (without terminus_font [
          "share/fonts/misc/fonts.dir"
          "share/fonts/terminus/fonts.scale"
          "share/fonts/terminus/fonts.dir"
        ])
        ttf_bitstream_vera
        unifont
      ];
  };

  imports = [];

  launchd.user.agents = {
    "lorri" = {
      serviceConfig = {
        WorkingDirectory     = (builtins.getEnv "HOME");
        EnvironmentVariables = {};
        KeepAlive            = true;
        RunAtLoad            = true;
        StandardOutPath      = "/var/tmp/lorri.log";
        StandardErrorPath    = "/var/tmp/lorri.log";
      };
      script = ''
        source ${config.system.build.setEnvironment}
        exec ${pkgs.lorri}/bin/lorri daemon
      '';
    };
  };

  nix = {
    # These are based on the number of CPU cores (check 'sysctl -n hw.ncpu')
    maxJobs       = 24;
    buildCores    = 12;

    # Build Linux derivations in a docker container
    distributedBuilds = true;
    buildMachines     = [
      {
        hostName = "nix-docker";
        sshKey   = "/Users/chris/.ssh/docker_rsa";
        systems  = [ "i686-linux" "x86_64-linux" ];
        supportedFeatures = [ "kvm" "big-parallel" ];
      }
    ];


    nixPath = (import ./nixPath.nix).list;

    # Auto upgrade nix package
    package = pkgs.nix;

    # Sandboxing is harder on macOS; not worth the hassle IMHO
    useSandbox = false;

    extraOptions = ''
      # Set by default by multi-user Nix installer
      build-users-group = nixbld
    '';
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      android_sdk.accept_license = true;
      permittedInsecurePackages = [
        "p7zip-16.02"
      ];
    };

    # NOTE: Overlays can add/change attributes in the 'pkgs' set, so they can't
    # depend on anything inside 'pkgs' (e.g. pkgs.fetchgit); otherwise we get an
    # infinite loop
    overlays = [
      (_: _: { sources = import ./nix/sources.nix; })

      # Useful Nix functions, used by the following overlays
      (import <nix-helpers/overlay.nix>)

      # Provides installApplication for macOS
      (self: super:
        import "${super.sources.cmacrae.outPath}/pkgs/apps.nix" self super)

      # Packages which aren't in nixpkgs yet (and which I don't feel like
      # maintaining in a formal way)
      (import <warbo-packages/overlay.nix>)

      # My own helper scripts
      (import <warbo-utilities/overlay.nix>)

      # Provides 'devGui', 'netCli', etc.
      (self: super:
        (import <nix-config/overrides/metaPackages.nix> self super).overrides)

      # Our own overrides go here
      (self: super: {
        inherit (self.callPackage <dotfiles/nixpkgs/androidApp.nix> {})
          androidApp apkpure;

        inherit (import <nixpkgs> {})
          gnumeric
        ;

        inherit (self.nixpkgs2009) aws-sam-cli;

        artemis-tools = self.callPackage
          <dotfiles/artemis-tools> {};

        async-profiler = self.callPackage
          ../async-profiler {};

        aws-helpers = self.callPackage <dotfiles/aws-helpers>          {};


        aws-lambda-rie =
          with rec {
            inherit (builtins) hasAttr trace;

            rev     = "0e5e1f0610dcc66dd2e6e3b7f7f71871c4eb6236";
            sha256  = "0w6zf108m7ni5sp5l5bsiarpphgvni0l8hn715ck8vhxhkp4mipn";
            warning = "WARNING: Override for aws-lambda-rie no longer needed";
            src     = builtins.fetchTarball {
              inherit sha256;
              name = "nixpkgs";
              url  = "https://github.com/nixos/nixpkgs/archive/${rev}.tar.gz";
            };
            pkgsLinux = import src {
              overlays = [];
              config   = {};
              system   = "x86_64-linux";
            };
            warn = x: if builtins.hasAttr "aws-lambda-rie" super
                         then trace warning x
                         else x;
          };
          warn pkgsLinux.aws-lambda-rie;

        cliclick    = self.callPackage <dotfiles/nixpkgs/cliclick.nix> {};

        # Patch Emacs so its window is better behaved on macOS (e.g. for tiling)
        emacs = super.emacs.overrideAttrs (old: {
          patches = (old.patches or []) ++ [
            (super.fetchurl {
              url = concatStringsSep "/" [
                "https://github.com/d12frosted/homebrew-emacs-plus/raw"
                "95e2add191d426ebb19ff150a517d1b0dc8cb676"
                "patches/fix-window-role.patch"
              ];
              sha256 = "0vfz99xi0mn3v7jzghd7f49j3x3b24xmd1gcxhdgwkjnjlm614mf";
            })
          ];
        });

        allowCollisions = pkg: pkg.overrideAttrs (old: {
          ignoreCollisions = true;
        });

        itstool = self.mkBin {
          name   = "itstool";
          script = ''
            #!/usr/bin/env bash
            CMD=$(head -n1 < "${super.itstool}"/bin/itstool |
                  cut -d ' ' -f1 | sed -e 's@#!@@g')
            "$CMD" -s "${super.itstool}"/bin/itstool "$@"
          '';
        };

        loop = self.mkBin {
          name = "loop";
          script = ''
            #!/usr/bin/env bash
            while true
            do
              "$@"
              sleep 1
            done
          '';
        };

        # Prevent build error when ApplicationServices isn't found
        lasem = super.lasem.overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ [
            self.darwin.apple_sdk.frameworks.ApplicationServices
          ];
        });

        latestGithub = { name, url, version }:
          with rec {
            inherit (builtins) compareVersions foldl' toJSON trace;

            versionsDrv = self.runCommand
              "latest-github-${name}"
              {
                inherit url;
                buildInputs = [
                  self.cacert
                  (self.python3.withPackages (p: [ p.beautifulsoup4 ]))
                ];

                default = self.writeScript "github-version-default.nix" ''
                  with builtins; fromJSON (readFile ./versions.json)
                '';

                script        = ./githubRelease.py;
                SSL_CERT_FILE = "${self.cacert}/etc/ssl/certs/ca-bundle.crt";
              }
              ''
                mkdir "$out"
                cp "$default" "$out/default.nix"
                python3 "$script" "$url" > "$out"/versions.json
              '';

            versions = import versionsDrv;

            latest = foldl'
              (highest: v: if compareVersions v highest == 1
                              then v
                              else highest)
              version
              versions;
          };
          if latest == version
             then (x: x)
          else trace (toJSON {
            inherit latest name version;
            warning = "out-of-date dependency";
          });

        nix_release = super.nix_release.override (old: {
          # Use system-wide Nix instead of attempting to use tunnel on macOS
          withNix = x: { buildInputs = []; } // x;
        });

        sbt = self.mkBin {
          name  = "sbt";
          paths = [ super.sbt ];
          script = ''
            #!/usr/bin/env bash
            set -e

            F=""
            [[ -e shellDeps.nix     ]] && F=shellDeps.nix
            [[ -e nix/shellDeps.nix ]] && F=nix/shellDeps.nix

            [[ -n "$F" ]] &&
              exec nix run -L -f "$F" -c sbt "$@"

            if [[ -e shell.nix       ]] ||
               [[ -e default.nix     ]] ||
               [[ -e nix/shell.nix   ]] ||
               [[ -e nix/default.nix ]]
            then
              exec nix-shell --run "sbt $*"
            fi

            exec sbt "$@"
          '';
        };

        # Scripts to bind to hotkeys
        shortcuts = self.callPackage ./shortcuts.nix {};

        # Broken in nixpkgs, but we don't care at the moment
        stylish-haskell   = self.dummyBuild "dummy-stylish-haskell";
        haskell-tng       = self.dummyBuild "dummy-haskell-tng";
        pretty-derivation = self.dummyBuild "dummy-pretty-derivation";
        nix-diff          = self.dummyBuild "dummy-nix-diff";

        wrappedShell = super.mkBin {
          name  = "wrappedShell";
          file  = self.warbo-utilities-scripts.wrappedShell;
          paths = [ self.bash self.coreutils ];
        };

        yabai =
          with self.sources;
          assert self.nixpkgs2009 ? yabai || self.die {
            error = "No yabai in Nixpkgs 20.09";
          };
          self.latestGithub {
            inherit (yabai) version;
            name = "yabai";
            url  = "https://github.com/koekeishiya/yabai/releases";
          } (super.yabai or self.nixpkgs2009.yabai).overrideAttrs (old: {
              inherit (yabai) version;
              src = yabai.outPath;
            });
      })
    ];
  };

  programs = {
    # Create /etc/bashrc that loads the nix-darwin environment.
    bash.enable = true;

    # Set up zsh (default on macOS Catalina) to load the nix-darwin environment
    zsh = {
      enable               = true;
      interactiveShellInit = ''
        # Taken from default macOS /etc/zshrc 2020-02-17 so that darwin-nix can
        # manage the file

        # Correctly display UTF-8 with combining characters.
        if [ "$TERM_PROGRAM" = "Apple_Terminal" ]; then
          setopt combiningchars
        fi

        disable log

        [ -r "/etc/zshrc_$TERM_PROGRAM" ] && . "/etc/zshrc_$TERM_PROGRAM"

        # The following was also in /etc/zshrc on 2020-02-17, but is clearly not
        # there by default
        # Nix
        if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]
        then
          . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
        fi
        # End Nix

        # This does exist in /etc/zshenv, but doesn't seem to work, so copy it
        #if [ -z "$__NIX_DARWIN_SET_ENVIRONMENT_DONE" ]; then
          . /nix/store/5r56ykssv4wrnh5pdl1vdpjn27xfs8wg-set-environment
        #fi

        # Ignore zsh's multi-line editing; we have Emacs for that, and it screws
        # up data without a trailing newline
        setopt nopromptcr
      '';
      loginShellInit = ''
        # Taken from default macOS /etc/zprofile 2020-02-17 so that darwin-nix
        # can manage the file
        if [ -x /usr/libexec/path_helper ]; then
          eval `/usr/libexec/path_helper -s`
        fi
      '';

      # I don't like nix-darwin's default, and it screws with Emacs
      promptInit = ''
        autoload -U promptinit && promptinit && prompt redhat
      '';
    };
  };

  services = {
    activate-system.enable = true;
    nix-daemon.enable      = true;

    # Tiling window manager
    yabai = import ./yabai.nix { inherit (pkgs) yabai; };
  };

  system = {
    activationScripts.postActivation.text = ''
      echo "Pointing Karabiner to /etc/static/karabiner" 1>&2
      D="$HOME"/.config/karabiner
      if [[ -e "$D" ]]
      then
        DEST=$(readlink -f "$D")
        if ! [[ "x$D" = "x/etc/static/karabiner" ]]
        then
          N=1
          while [[ -e "$D.backup$N" ]]; do N=$(( N + 1 )); done
          mv -v "$D" "$D.backup$N"
          ln -sv /etc/static/karabiner "$D"
        fi
      else
        ln -sv /etc/static/karabiner "$D"
      fi
      unset D

      echo "Populating Applications folder for dock" 1>&2
      D="$HOME"/.local/share/Applications
      [[ -d "$D" ]] || mkdir -p "$D"
      find "$D" -maxdepth 1 -type l | while read -r F
      do
        rm "$F"
      done
      for APP in "$HOME"/Applications/*
      do
        ln -s "$APP" "$D"/
      done
      unset D
    '';

    defaults = {
      #NSGlobalDomain = {
      #  AppleKeyboardUIMode = 3;
      #  ApplePressAndHoldEnabled = false;
      #};

      dock = {
        autohide    = true;
        launchanim  = false;
        orientation = "bottom";
      };

      finder = {
        AppleShowAllExtensions         = true;
        QuitMenuItem                   = true;
        FXEnableExtensionChangeWarning = false;
      };

      #trackpad.Clicking = true;
    };

    # Used for backwards compatibility, read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 4;
  };

  time.timeZone = "Europe/London";
}
