{ fetchFromGitHub, foldAttrs', lib, prefixFlatten, skhd }:
with lib;
{
  enable  = true;
  package = skhd.overrideAttrs (old: rec {
    version = "0.3.5";
    src     = fetchFromGitHub {
      owner  = "koekeishiya";
      repo   = "skhd";
      rev    = "v${version}";
      sha256 = "0x099979kgpim18r0vi9vd821qnv0rl3rkj0nd1nx3wljxgf7mrg";
    };
  });

  # TODO: Refactor
  # TODO: Pick more ergonomic keys (remap Option to Super?)
  skhdConfig =
    with rec {
      # The skhd config has the form "keys : commands". Since the commands
      # govern the semantics it makes more sense for us to specify them the
      # other way around.

      possiblyUseful = {
        # launchers
        #"open -nb io.alacritty" = cmd + ctrl - return;
        #"open -b org.gnu.Emacs" = cmd + ctrl - i;

        # make floating window fill left-half of screen
        # "yabai -m window --grid 1:2:0:0:1:1" = shift + alt - left

        # make floating window fill right-half of screen
        # "yabai -m window --grid 1:2:1:0:1:1" = shift + alt - right  :

        # create desktop, move window and follow focus - uses jq for parsing json (brew install jq)
        # shift + cmd - n : yabai -m space --create && \
                          # index="$(yabai -m query --spaces --display | jq 'map(select(."native-fullscreen" == 0))[-1].index')" && \
                          # yabai -m window --space "''${index}" && \
                          # yabai -m space --focus "''${index}"

        # create desktop and follow focus - uses jq for parsing json (brew install jq)
        # cmd + alt - n : yabai -m space --create && \
        #                 index="$(yabai -m query --spaces --display | jq 'map(select(."native-fullscreen" == 0))[-1].index')" && \
        #                 yabai -m space --focus "''${index}"

        # destroy desktop
        # cmd + alt - w : yabai -m space --destroy

        # focus monitor
        # TODO: [Darwin](skhd/yabai) Directional monitor focus
        #       yabai's API provides display position offsets.
        #       yabai -m query --displays | jq
        # ctrl + alt - x  : yabai -m display --focus recent
        # ctrl + alt - z  : yabai -m display --focus prev
        # ctrl + alt - c  : yabai -m display --focus next
        # ctrl + alt - 1  : yabai -m display --focus 1
        # ctrl + alt - 2  : yabai -m display --focus 2
        # ctrl + alt - 3  : yabai -m display --focus 3

        # send window to monitor and follow focus
        # ctrl + cmd - x  : yabai -m window --display recent; yabai -m display --focus recent
        # ctrl + cmd - z  : yabai -m window --display prev; yabai -m display --focus prev
        # ctrl + cmd - c  : yabai -m window --display next; yabai -m display --focus next
        # ctrl + cmd - 1  : yabai -m window --display 1; yabai -m display --focus 1
        # ctrl + cmd - 2  : yabai -m window --display 2; yabai -m display --focus 2
        # ctrl + cmd - 3  : yabai -m window --display 3; yabai -m display --focus 3

        # # change layout of desktop
        # ctrl + alt - a : yabai -m space --layout bsp
        # ctrl + alt - d : yabai -m space --layout float
      };

      # Most of our shortcuts are for yabai, since it's designed to be used
      # in conjunction with a hotkey daemon like skhd. These attrsets follow
      # the yabai option names to reduce boilerplate.
      yabaiCfg =
        with {
          # The main 'hotkey' for invoking Yabai actions. Note that this
          # function adds a '-' that skhd expects, so it should come at the end
          # of any other modifiers (e.g. alt or shift)
          mod = k: "lalt - ${k}";

          # Extra modifiers. Note that these don't add the '-' that skhd expects
          # at the end of the modifiers.
          alt   = k: "alt   + ${k}";
          shift = k: "shift + ${k}";
        };
        {
          space = {
            # balance size of windows; write explicitly to get +/- right
            balance = "shift + alt - 0";

            focus = {
              "recent" = mod "tab";
              "prev"   = mod "p";
              "next"   = mod "n";
              "1"      = mod "1";
              "2"      = mod "2";
              "3"      = mod "3";
              "4"      = mod "4";
              "5"      = mod "5";
              "6"      = mod "6";
              "7"      = mod "7";
              "8"      = mod "8";
              "9"      = mod "9";
              "10"     = mod "0";
            };
          };
          window = {
            focus = {
              "west"  = mod "h";
              "south" = mod "j";
              "north" = mod "k";
              "east"  = mod "l";
            };

            # make floating window fill screen
            grid = { "1:1:0:0:1:1" = mod "f"; };

            # set insertion point in focused container
            insert = {
              "west"  = alt (mod "h");
              "south" = alt (mod "j");
              "north" = alt (mod "k");
              "east"  = alt (mod "l");
            };

            # send window to desktop and follow focus
            space = {
              "recent; yabai -m space --focus recent" = shift (mod "tab");
              "prev  ; yabai -m space --focus prev"   = shift (mod "p"  );
              "next  ; yabai -m space --focus next"   = shift (mod "n"  );
              "1     ; yabai -m space --focus 1"      = shift (mod "1"  );
              "2     ; yabai -m space --focus 2"      = shift (mod "2"  );
              "3     ; yabai -m space --focus 3"      = shift (mod "3"  );
              "4     ; yabai -m space --focus 4"      = shift (mod "4"  );
              "5     ; yabai -m space --focus 5"      = shift (mod "5"  );
              "6     ; yabai -m space --focus 6"      = shift (mod "6"  );
              "7     ; yabai -m space --focus 7"      = shift (mod "7"  );
              "8     ; yabai -m space --focus 8"      = shift (mod "8"  );
              "9     ; yabai -m space --focus 9"      = shift (mod "9"  );
              "10    ; yabai -m space --focus 10"     = shift (mod "0"  );
            };
            toggle = {
              # toggle window split type
              split = mod "e";

              # float / unfloat window and center on screen
              "float; yabai -m window --grid 4:4:1:1:2:2" = mod "space :";
            };

            # move window
            warp = {
              "west"  = shift (mod "h");
              "south" = shift (mod "j");
              "north" = shift (mod "k");
              "east"  = shift (mod "l");
            };
          };
        };

      # Add boilerplate to option names: '-m' at the outer level, '--' for inner
      prefixed = mapAttrs'
        (m: x: {
          name  = "yabai -m ${m} ";
          value = mapAttrs'
            (option: y: {
              name  = "--${option} ";
              # Some options are used on their own, others take suboptions
              value = if isString y
                         then { "" = y; }
                         else y;
            })
            x;
        })
        yabaiCfg;

      # Turn nested attrsets into one big attrset
      processed = prefixFlatten (prefixFlatten prefixed);
    };
    foldAttrs' (cmd: key: result: result + ''
                 ${key} : ${cmd}
               '')
               ""
               processed;
}
