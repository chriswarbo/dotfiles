{ config, pkgs, ... }:

with builtins;
with {
  # Grab useful configs from other people
  cmacraeNixpkgs = fetchGit {
    url    = https://github.com/cmacrae/.nixpkgs.git;
    rev    = "d4b51eb414b0edaffaeee9b926c32b118014c4fa";
  };
};
{
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

      "ssh/ssh_config".text = ''
        # We want access to warbo@github.com and chriswarbo@github.com, but
        # GitHub don't let us specify the username: it's always git@github.com,
        # and we're identified by our SSH key. This means we need to send a
        # different key depending on which user we're trying to be.
        # Let's use chriswarbo for the default github.com (so accessing ZipAbout
        # repos is easiest), and make an alias for warbo for those few times we
        # need such access.
        Host github.com-warbo
          HostName github.com
          User git
          IdentityFile ${toString <home/.ssh/warbo_rsa>}

        # Might as well provide this alias too, but github.com will also work
        Host github.com-chriswarbo
          HostName github.com
          User git
          IdentityFile ${toString <home/.ssh/id_rsa>}

        # Taken from default macOS /etc/ssh/ssh_config
        Host *
          SendEnv LANG LC_*
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
    systemPackages =
      with pkgs;
      with lib;
      with {
        # Hacky things and macOS-specific things here, for the time being
        # TODO: Can we do this in a nicer way? (Copypasta from warbo-utilities)
        artemisWrapper = mkBin {
          name   = "artemis";
          script = ''
            #!/usr/bin/env bash
            export EDITOR=emacsclient
            if [[ "x$1" = "xclose" ]]
            then
                shift
                # Shortcut to close the given Artemis issue ID

                [[ "$#" -eq 1 ]] || {
                    echo "artemis-close requires (prefix of) an issue ID. Open issues:" 1>&2
                    artemis list 1>&2
                    exit 1
                 }

                artemis add "$1" -p state=resolved -p resolution=fixed
            else
                git artemis "$@"
            fi
          '';
        };
      };
      [
        # binutils and gcc both provide bin/ld
        (devCli.overrideAttrs (old: { ignoreCollisions = true; }))
        devGui
        docCli
        docGui
        netCli

        artemisWrapper
        docker  # FIXME: Do we actually need this command in the global env?

        (callPackage ./displayplacer.nix {})

        lorri   # Needed by lorri launchd service defined below
        direnv  # Needed by lorri
        #gnumeric

        cmus  # Useful at home

        shortcuts.package  # Commands used by our keyboard shortcuts

        # AWS helper
        (mkBin rec {
          name   = "aws-login";
          paths  = [ bash awscli ];
          script = with { unlines = concatStringsSep "\n"; }; ''
            #!/usr/bin/env bash
            set -e
            cd "$HOME"

            if [ $# -lt 1 ]
            then
              echo "${name}: Log in to AWS CLI session, using MFA token" 1>&2
              echo "Example: ${name} 123456" 1>&2
              exit 2
            fi

            export AWS_PROFILE=prod

            MFA_SERIAL_NUMBER=$(aws iam list-mfa-devices                \
                                    --query 'MFADevices[].SerialNumber' \
                                    --output text)

            QUERY='Credentials.[AccessKeyId,SecretAccessKey,SessionToken]'
            DATA=$(aws sts get-session-token              \
                     --serial-number "$MFA_SERIAL_NUMBER" \
                     --query         "$QUERY"             \
                     --output        text                 \
                     --token-code    "$1")

            ${with { data = i: ''$(echo "$DATA" | cut -f${toString i})''; };
              unlines (mapAttrsToList
                (var: val: ''
                  VAL="${val}"
                  aws configure set "${var}" "$VAL" --profile=mfa
                  echo export ${toUpper var}="$VAL"
                '')
                {
                  aws_access_key_id     = data 1;
                  aws_secret_access_key = data 2;
                  aws_session_token     = data 3;
                  region                = "eu-west-2";
                })}
          '';
        })

        # GUI macOS applications

        (installApplication rec {
          name       = "Firefox";
          version    = "78.0.2";
          sourceRoot = "Firefox.app";
          src        = fetchurl {
            name   = "firefox-${version}.dmg";
            url    = "https://ftp.mozilla.org/pub/firefox/releases/" +
                     version + "/mac-EME-free/en-GB/Firefox%20${version}.dmg";
            sha256 = "1l1b6m1i9hya4awsp6pwkjlpbpk2mnlcpnmll45dxb8qcc2dn6gx";
          };
          description = "Firefox browser";
          homepage    = https://www.getfirefox.com;
        })

        (installApplication rec {
          name       = "Postman";
          version    = "7.20.1";
          sourceRoot = "Postman.app";
          src        = fetchurl {
            name   = "postman-${version}.zip";
            url    = "https://dl.pstmn.io/download/version/${version}/osx64";
            sha256 = "06yziywjs0jxmax2j5bx5imhs54alplrqv6mk04wqw0r5hwbmvzd";
          };
          description = "GUI for testing HTTP requests and responses";
          homepage    = https://www.getpostman.com;
        })

        (installApplication rec {
          name       = "Slack";
          version    = "4.6.0";
          sourceRoot = "Slack.app";
          src        = fetchurl {
            name   = "slack-${version}.zip";
            url    = "https://downloads.slack-edge.com/mac_releases" +
                     "/Slack-${version}-macOS.zip";
            sha256 = "15hppw4b2snx2fanprvk8vm5l8kfl9x4p5aqnlvqbiwbbkk890hv";
          };
          description = "Desktop client for Slack messenger";
          homepage    = https://www.slack.com;
        })

        (installApplication rec {
          name       = "VNCViewer";
          version    = "6.20.113";
          sourceRoot = "VNC Viewer.app";
          src        = fetchurl {
            name   = "real-vnc-viewer-${version}.dmg";
            url    = "https://www.realvnc.com/download/file/viewer.files/" +
                     "VNC-Viewer-${version}-MacOSX-x86_64.dmg";
            sha256 = "d6035174e9e4aa2e281b49abc953b75c915a1eca9173d56140ddfa3c129197dd";
          };
          description = "RealVNC client";
          homepage    = https://www.realvnc.com;
        })
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
    #enableDefaultFonts      = true;
    /*fontconfig.defaultFonts = {
      monospace = [ "Droid Sans Mono" ];
      sansSerif = [ "Droid Sans"      ];
      serif     = [ "Droid Sans"      ];
    };*/
    fonts = [
      pkgs.anonymousPro
      #pkgs.droid-fonts
      pkgs.liberation_ttf
      pkgs.terminus_font
      pkgs.ttf_bitstream_vera
    ];
  };

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
    # Auto upgrade nix package
    package = pkgs.nix;

    # Sandboxing is harder on macOS; not worth the hassle IMHO
    useSandbox = false;

    # These are based on the number of CPU cores (check 'sysctl -n hw.ncpu')
    maxJobs    = 24;
    buildCores = 12;

    # These entries can be used as <foo> or <foo/bar.txt> within Nix. We should
    # always try to use paths like these in Nix rather than strings, since Nix
    # will check whether paths we refer to actually exist. For example if we use
    # the path <home/ssh/config> then Nix will abort evaluation if it doesn't
    # exist; this is usually preferable to using strings like
    # (<home> + ".ssh/config") which will be evaluated without error, only to
    # cause "file not found" problems later on (in a builder if we're lucky; if
    # we're not it could get written to scripts or config files which we only
    # notice when running them at some arbitrary point in the future!)

    # NOTE: Paths are used in two different ways, depending on the behaviour we
    # want:
    #  - Sometimes we want to take a snapshot of the files we reference. For
    #    example, we might use libraries like <nix-helpers> or read options from
    #    <home/.config/foo>. If these paths get hard-coded into our builders,
    #    binaries, etc. then the .drv files will give different results whenever
    #    we update/alter those configs. For example, if a working package gets
    #    garbage collected, we might never be able to rebuild it again; even if
    #    we still have the .drv file!
    #    To avoid this we should add a snapshot of these paths to the Nix store,
    #    so that everything we reference is immutable. This is what Nix will do
    #    by default if we use a path as a string, e.g.
    #        "ls ${<nix-helpers>}"
    #        builtins.toJSON [ <nix-helpers> ]
    #        runCommand "foo" { helpers = <nix-helpers>; } "bar"
    #    Be careful that your snapshots aren't too big! For example, don't keep
    #    adding snapshots of your entire home directory just to reference a
    #    single file!
    #  - Other times we want a path to appear literally, e.g. if we're writing a
    #    downloader's config we want it to save things into <home/Downloads>,
    #    not into some snapshot of that directory (also, we can't save into an
    #    immutable filesystem!). In these cases we should send the path through
    #    to 'builtins.toString' function, e.g.
    #        { destination = builtins.toString <home/Downloads>; }

    # NOTE: Relying on these paths causes a bootstrapping problem: our config
    # depends on these paths, but these paths are made available by our config.
    # The first time we try to activate this config we'll get an error ("file
    # foo was not found in the Nix search path"); to break this cycle we need to
    # write them out manually the first time, e.g.
    #     NIX_PATH="$NIX_PATH:home=$HOME:..." darwin-rebuild switch
    # From then on it should work without problems.
    nixPath =
      with {
        combine = name: path: rest: [ "${name}=${path}" ] ++ rest;
        github  = owner: repo: branch:
          "https://github.com/${owner}/${repo}/archive/${branch}.tar.gz";
        repo    = repo: "$HOME/repos/" + repo;
      };
      pkgs.foldAttrs' combine [] {
                darwin = github "LnL7" "nix-darwin" "master";
                  home = "$HOME";
            nix-config = repo "nix-config";
           nix-helpers = repo "nix-helpers";
               nixpkgs = github "nixos" "nixpkgs" "nixpkgs-unstable";
        warbo-packages = repo "warbo-packages";
      };

    extraOptions = ''
      # Set by default by multi-user Nix installer
      build-users-group = nixbld
    '';
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "p7zip-16.02"
      ];
    };

    # NOTE: Overlays can add/change attributes in the 'pkgs' set, so they can't
    # depend on anything inside 'pkgs' (e.g. pkgs.fetchgit); otherwise we get an
    # infinite loop
    overlays           = [
      # Useful Nix functions, used by the following overlays
      (import <nix-helpers/overlay.nix>)

      # Provides installApplication for macOS
      (import "${cmacraeNixpkgs}/pkgs/apps.nix")

      # Packages which aren't in nixpkgs yet (and which I don't feel like
      # maintaining in a formal way)
      (import <warbo-packages/overlay.nix>)

      # Provides 'devGui', 'netCli', etc.
      (self: super: builtins.getAttr "overrides"
        (import <nix-config/overrides/metaPackages.nix> self super))

      # Our own overrides go here
      (self: super: {
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

        itstool = self.mkBin {
          name   = "itstool";
          script = ''
            #!/usr/bin/env bash
            CMD=$(head -n1 < "${super.itstool}"/bin/itstool |
                  cut -d ' ' -f1 | sed -e 's@#!@@g')
            "$CMD" -s "${super.itstool}"/bin/itstool "$@"
          '';
        };

        # Prevent build error when ApplicationServices isn't found
        lasem = super.lasem.overrideAttrs (old: {
          buildInputs = (old.buildInputs or []) ++ [
            self.darwin.apple_sdk.frameworks.ApplicationServices
          ];
        });

        nix_release = super.nix_release.override (old: {
          # Use system-wide Nix instead of attempting to use tunnel on macOS
          withNix = x: { buildInputs = []; } // x;
        });

        # Scripts to bind to hotkeys
        shortcuts = self.callPackage ./shortcuts.nix {};

        # Broken in nixpkgs, but we don't care at the moment
        stylish-haskell = self.dummyBuild "dummy-stylish-haskell";
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
    yabai = import ./yabai.nix { inherit config pkgs; };
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
