{ fetchFromGitHub, foldAttrs', lib, merge, prefixFlatten, skhd }:
with builtins;
with lib;
with { unwords = concatStringsSep " "; };
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
      # in conjunction with a hotkey daemon like skhd.
      yabaiCfg =
        with {
          # The main 'hotkey' for invoking Yabai actions. Note that this
          # function adds a '-' that skhd expects, so it should come at the end
          # of any other modifiers (e.g. alt or shift)
          mod = k: "lalt - ${k}";

          # Extra modifiers. Note that these don't add the '-' that skhd expects
          # at the end of the modifiers; either use them in conjunction with
          # 'mod' e.g. 'shift (mod "j")' or put '-' explicitly e.g. 'alt "- j"'.
          alt   = k: "alt   + ${k}";
          shift = k: "shift + ${k}";
        };
        merge [
          # Focusing and moving windows. If we hit either end of the window
          # list, roll over to the other.
          {
            "${       mod "j" }" = "yabai -m window --focus next || " +
                                   "yabai -m window --focus first";
            "${       mod "k" }" = "yabai -m window --focus prev || " +
                                   "yabai -m window --focus last";
            "${shift (mod "j")}" = "yabai -m window --swap  next || " +
                                   "yabai -m window --swap  first";
            "${shift (mod "k")}" = "yabai -m window --swap  prev || " +
                                   "yabai -m window --swap  last";
          }

          # Hotkeys for switching to a particular space (by label)
          (with rec {
            # Bring the given space to the focused display, then focus the space:
            # - Put two non-visible spaces on each display (in case one moves);
            # - the current display contains this space || space --display;
            # - space --focus N

            # Picks a display with more than 2 spaces (guaranteed since we have
            # fewer than 5 displays!)
            pickGreedyDisplay = unwords [
              "yabai -m query --displays |"
              "jq 'map(select(.spaces | length | . > 2)) | .[] | .index' |"
              "head -n1"
            ];

            # Find a non-visible space from a display with many spaces
            pickInvisibleSpace = unwords [
              "yabai -m query --spaces --display $(${pickGreedyDisplay}) |"
              "jq 'map(select(.visible | . == 0)) | .[] | .index' |"
              "head -n1"
            ];

            # Make sure each display has at least two spaces, so we can move one
            ensureDisplaysHaveSpaces = unwords [
              # Loop through display indices which have fewer than 2 spaces
              "yabai -m query --displays |"
                "jq 'map(select(.spaces | length | . < 2)) | .[] | .index' |"
                "while read -r D; do"
                  # Move a non-visible space to display $D from one with many
                  "yabai -m space $(${pickInvisibleSpace}) --display $D;"
                "done"
            ];

            go = n: with { s = toString n; }; unwords [
              "${ensureDisplaysHaveSpaces};"
              "yabai -m space l${s} --display;"
              "yabai -m space --focus l${s}"
            ];
          };
          listToAttrs (map (n: {
                             name  = mod (toString n);
                             value = go n;
                           })
                           (range 0 9)))

          # Send focused window to a particular space (by label)
          (listToAttrs (map (n: {
                              name  = shift (mod (toString n));
                              value = "yabai -m window --space l${toString n}";
                            })
                            (range 0 9)))

          # Switch between displays, cycling around when we hit the end of list
          {
            "${mod "left" }" = "yabai -m display --focus prev || " +
                               "yabai -m display --focus last";
            "${mod "right"}" = "yabai -m display --focus next || " +
                               "yabai -m display --focus first";
          }

          # General commands
          {
            # Treat "west" area like XMonad's "main" area
            "${mod "return"}" = "yabai -m window --swap west";

            "${mod "space"}" = "yabai -m window --toggle split";

            # Tile/float the focused window
            # TODO: Add queries so they only do one or the other
            "${       mod "t" }" = "yabai -m window --toggle float";
            "${shift (mod "t")}" = "yabai -m window --toggle float";
          }

          # Window resizing (emulates XMonad)
          {
            # Vertical resizing is easy: just change where the bottom is
            "${mod "i"}" = "yabai -m window --resize bottom:0:-60";
            "${mod "o"}" = "yabai -m window --resize bottom:0:60";

            # Horizontal requires offset calculations
            "${mod "h"}" = unwords [
              "expr $(yabai -m query --windows --window | jq .frame.x) \\< 20"
              "&&"
              "yabai -m window --resize right:-60:0"
              "||"
              "yabai -m window --resize left:-60:0"
            ];
            "${mod "l"}" = unwords [
              "expr $(yabai -m query --windows --window | jq .frame.x) \\< 20"
              "&&"
              "yabai -m window --resize right:60:0"
              "||"
              "yabai -m window --resize left:60:0"
            ];
          }

          # Trigger a re-jig of our displays/spaces/etc. This would be useful to
          # put in Yabai's startup config, but doesn't seem to work (maybe only
          # "config" options work there?).
          # TODO: Prefer destroying empty spaces, to reduce window shuffling
          {
            "${mod "r"}" = unwords ([
              # Ensure we have 10 spaces in total
              "while [[ $(yabai -m query --spaces | jq 'length') -gt 10 ]];"
              "do"
                # If there's only one space on this display, switch to another
                "if [[ $(yabai -m query --spaces --display | jq 'length')"
                       "-eq 1 ]];"
                "then"
                  "yabai -m display --focus next;"
                  #"sleep 0.2;"
                "fi;"
                "yabai -m space --destroy;"
              "done;"
              "while [[ $(yabai -m query --spaces | jq 'length') -lt 10 ]];"
              "do"
                "yabai -m space --create;"
                #"sleep 0.2"
              "done;"
            ] ++

            # Spaces are indexed, but that order can change, e.g. when moving
            # them between displays. We'll use labels instead, since they're
            # more stable: the labels are "l" followed by a number (current
            # index - 1). These labels should be used by our keybindings,
            # rather than the indices.
            map (n: with { s = toString (n - 1); };
                    "yabai -m space ${toString n} --label l${s};")
                (range 1 10) ++

            # Dummy command, to prevent the previous ';' causing trouble
            ["true"]);
          }

          /*
            # balance size of windows; write explicitly to get +/- right
            #yabai -m space --balance = "shift + alt - 0";

            yabai -m space --focus = {
              "yabai -m space --focus recent" = mod "tab";
              "yabai -m space --focus prev"   = mod "p";
              "yabai -m space --focus next"   = mod "n";

            };
          };

          "yabai -m window --focus west"  = mod "h";
          "yabai -m window --focus south" = mod "j";
          "yabai -m window --focus north" = mod "k";
          "yabai -m window --focus east"  = mod "l";

          # make floating window fill screen
          #yabai -m window --grid "1:1:0:0:1:1" = mod "f";

          # set insertion point in focused container
          "yabai -m window --insert west"  = alt (mod "h");
          "yabai -m window --insert south" = alt (mod "j");
          "yabai -m window --insert north" = alt (mod "k");
          "yabai -m window --insert east"  = alt (mod "l");

          # send window to desktop and follow focus
          "yabai -m window --space recent; yabai -m space --focus recent" = shift (mod "tab");
          "yabai -m window --space prev  ; yabai -m space --focus prev"   = shift (mod "p"  );
          "yabai -m window --space next  ; yabai -m space --focus next"   = shift (mod "n"  );
          "yabai -m window --space 1     ; yabai -m space --focus 1"      = shift (mod "1"  );
          "yabai -m window --space 2     ; yabai -m space --focus 2"      = shift (mod "2"  );
          "yabai -m window --space 3     ; yabai -m space --focus 3"      = shift (mod "3"  );
          "yabai -m window --space 4     ; yabai -m space --focus 4"      = shift (mod "4"  );
          "yabai -m window --space 5     ; yabai -m space --focus 5"      = shift (mod "5"  );
          "yabai -m window --space 6     ; yabai -m space --focus 6"      = shift (mod "6"  );
          "yabai -m window --space 7     ; yabai -m space --focus 7"      = shift (mod "7"  );
          "yabai -m window --space 8     ; yabai -m space --focus 8"      = shift (mod "8"  );
          "yabai -m window --space 9     ; yabai -m space --focus 9"      = shift (mod "9"  );
          "yabai -m window --space 10    ; yabai -m space --focus 10"     = shift (mod "0"  );

          # float / unfloat window and center on screen
          #${mod "space :"} = "yabai -m window --toggle float; yabai -m window --grid 4:4:1:1:2:2" = ;
          };*/
        ];
    };
    foldAttrs' (key: cmd: result: result + ''
                 ${key} : ${cmd}
               '')
               ""
               yabaiCfg;
}
