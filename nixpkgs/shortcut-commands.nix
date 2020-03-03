# Commands to invoke when we press hot keys. These are mostly for controlling
# the Yabai window manager.
{ attrsToDirs', lib, wrap }:

with builtins;
with lib;
with rec {
  # The spaces we're going to use. Always use these variables, instead
  # of hard-coding, to ensure consistency when changing the number.
  spaces = range 1 9;  # Ignore 0 to avoid off-by-one nonsense
  count  = toString (length spaces);
  labels = map (n: "l${toString n}") spaces;

  unlines = concatStringsSep "\n";
  unwords = concatStringsSep " ";
};
attrsToDirs' "shortcut-commands" {
  bin = mapAttrs (name: script: wrap {
                   inherit name;
                   script = ''
                     #!/usr/bin/env bash
                     set -e
                     ${script}
                   '';
                 }) {
    shortcut-find-unlabelled = ''
      # Assume we didn't find anything
      CODE=1

      SPACES=$(yabai -m query --spaces)

      # Note: 'label' is a keyword in jq
      UNLABELLED=$(echo "$SPACES" | jq '${unwords [
        "map(select(.label as $l      |"
                    "${toJSON labels} |"
                    "map(. == $l)     |"
                    "any | not))      |"
        "map(.index)"
      ]}')
      if echo "$UNLABELLED" | jq -e 'length | . > 0' > /dev/null
      then
        CODE=0
        echo "$UNLABELLED" | jq '.[]'
      fi

      # Look for spaces with duplicate labels
      ${unlines
        (map (l: ''
               if echo "$SPACES" | jq -e '${unwords [
                 "map(select(.label | . == ${toJSON l} )) |"
                 "length | . > 1"
               ]}' > /dev/null
               then
                 # This label is applied to multiple spaces, spit
                 # out the index of one of them (arbitrarily)
                 echo "$SPACES" | jq '${unwords [
                   "map(select(.label | . == ${toJSON l} )) |"
                   ".[0] | .index"
                 ]}'
                 CODE=0
               fi
             '')
             labels)}

      # Let other applications know if we found anything
      # Note that in normal operation we should only be called when
      # we need to find a space for a label, which implies that
      # there should be at least one available; hence the warning.
      [[ "$CODE" -eq 0 ]] ||
        echo "Warning: Couldn't find spaces with dodgy labels" 1>&2
      exit "$CODE"
    '';

    # Destroy spaces if we have too many, create if we don't have enough
    shortcut-populate-spaces = ''
      # Ensure we have ${count} spaces in total
      SPACES=$(yabai -m query --spaces)
      D=$(echo "$SPACES" |
          jq 'map(select(.focused == 1)) | .[] | .display')
      SWITCHED=0
      while [[ $(echo "$SPACES" | jq 'length') -gt ${count} ]]
      do
        echo "Need to add more spaces" 1>&2
        # If there's only one space on this display, switch to another
        if [[ $(yabai -m query --spaces --display |
                jq 'length') -eq 1 ]]
        then
          echo "Switching display to avoid underpopulation" 1>&2
          SWITCHED=1
          yabai   -m display --focus next ||
            yabai -m display --focus first
        fi
        yabai -m space --destroy || true
        SPACES=$(yabai -m query --spaces)
      done
      [[ "$SWITCHED" -eq 0 ]] || yabai -m display --focus "$D" || true
      unset D
      unset SWITCHED

      if [[ $(echo "$SPACES" | jq 'length') -lt ${count} ]]
      then
        echo "Need to create more spaces" 1>&2
        for N in seq 1 $(echo "$SPACES" | jq 'length | ${count} - .')
        do
          yabai -m space --create || true
        done
        SPACES=$(yabai -m query --spaces)
      fi
    '';

    shortcut-fix-up-spaces = ''
      # Re-jigs our displays/spaces/etc. to work like XMonad. Specifically:
      #  - We want a fixed number of spaces (destroy/create to enforce this)
      #  - "Switch to space N" should bring that space to the focused
      #    display, rather than changing which display is focused.
      #
      # This would be nice to put in Yabai's startup config, but doesn't
      # seem to work (maybe only "config" options work there?).
      # TODO: Prefer destroying empty spaces, to reduce window shuffling

      shortcut-populate-spaces
      shortcut-label-spaces
    '';

    shortcut-label-spaces = ''
      # Spaces are indexed, but that order can change, e.g. when moving
      # them between displays. We'll use labels instead, since they're
      # more stable: the labels are "l" followed by the current index.
      # These labels should be used by our keybindings, rather than the
      # indices.
      function info {
        [[ -z "$DEBUG" ]] || echo "label-spaces: $@" 1>&2
      }

      ${unlines (map (n: with { s = toString n; }; ''
                       # Skip this label if a space already has it
                       info "Checking if a space is already labelled l${s}"
                       if echo "$SPACES" |
                          jq -e 'map(select(.label == "l${s}")) | ${""
                                 } length | . == 0' > /dev/null
                       then
                         info "Labelling space l${s}"
                         # Find a space with a dodgy or duplicate label.
                         # If we're here then it must be the case that:
                         #  - We've got the right number of spaces
                         #  - There isn't a space with this label
                         # This implies that there must be a space with
                         # no label, or a dodgy label, or a duplicate
                         # label, which shortcut-find-unlabelled will
                         # give us
                         UL=$(shortcut-find-unlabelled | head -n1)
                         yabai -m space "$UL" --label l${s} || true
                         SPACES=$(yabai -m query --spaces)
                       else
                         info "Space l${s} already exists, nothing to do"
                       fi
                     '')
                     spaces)}
    '';

    shortcut-fix-up-emacs = ''
      # Force all Emacs windows to be "zoomed", i.e. take up their whole
      # space. Since Emacs doesn't tile nicely, this at least resizes it
      # to fit its current display.

      osascript -e 'tell application "Emacs"
                      repeat with x from 1 to (count windows)
                        tell window x
                          set zoomed to true
                        end tell
                      end repeat
                    end tell'
    '';

    shortcut-arrange-spaces = ''
      # To minimise disruption if/when Yabai dies, we can use this script to
      # arrange spaces in order of their labels. This way, relabelling them
      # should result in no changes, and hence no need to move windows.

      # macOS numbers spaces on one display then another, and so on.
      # This means that, for example, l1 will be out of order if it's on
      # display 2; since whatever space(s) is on display 1 will come
      # first. The same applies to the last space having to be on the
      # highest-numbered display.
      # Note that Yabai's display numbering *seems* to correspond to
      # that of macOS, at least on my setup. This assumption might be
      # wrong!

      function info {
        [[ -z "$DEBUG" ]] || echo "arrange-spaces: $@" 1>&2
      }

      function indexOf {
        yabai -m query --spaces |
          jq "map(select(.label == \"$1\")) | .[] | .index"
      }

      function displayOf {
        yabai -m query --spaces |
          jq "map(select(.label == \"$1\")) | .[] | .display"
      }

      function spacesInOrder {
        info "Checking if spaces are in order"
        SPACES=$(yabai -m query --spaces)
        for N in ${unwords (map toString spaces)}
        do
          info "Checking space $N"
          [[ $(indexOf "l$N") -eq "$N" ]] || return 1
          info "Space $N is in the correct place"
        done
        info "All spaces are in the correct place"
        return 0
      }

      info "Ensuring spaces are labelled first"
      shortcut-fix-up-spaces

      # Evenly distribute spaces across displays (easier to have a fixed
      # target than enforce constraints on some arbitrary arrangement)
      # TODO: Hardcoded to 2 displays at the moment.
      DCOUNT=$(yabai -m query --displays | jq 'length')
      info "Found $DCOUNT displays"
      [[ "$DCOUNT" -lt 3 ]] || {
        echo "Found $DCOUNT displays; we can only handle 1 or 2" 1>&2
        exit 1
      }
      if [[ "$DCOUNT" -gt 1 ]]
      then
        info "External display is plugged in; we assume it's index 2"
        for M in ${unwords (map toString spaces)}
        do
          if [[ "$M" -lt $(( ${count} / 2 )) ]]
          then
            D=1
          else
            D=2
          fi
          DM=$(displayOf "l$M")
          info "Ensuring space $M is on display $D; it's on $DM"
          if [[ "$DM" -ne "$D" ]]
          then
            info "Moving space $M from display $DM to display $D"
            yabai -m space "l$M" --display "$D"
          fi
        done
      fi

      # Rearrange spaces in order of labels
      for D in $(seq 1 "$DCOUNT")
      do
        while ! spacesInOrder
        do
          for M in ${unwords (map toString spaces)}
          do
            # We only execute a movement half the time; the randomness
            # should prevent us getting stuck in a loop
            if [[ $(indexOf "l$M") -lt "$M" ]]
            then
              [[ $(( RANDOM % 2 )) -eq 0 ]] ||
                yabai -m space "l$M" --move next
            fi

            if [[ $(indexOf "l$M") -gt "$M" ]]
            then
              [[ $(( RANDOM % 2 )) -eq 0 ]] ||
                yabai -m space "l$M" --move prev
            fi
          done
        done
      done
    '';

    # mod-j
    shortcut-next-window = ''
      yabai -m window --focus next ||
      yabai -m window --focus first
    '';

    # mod-k
    shortcut-prev-window = ''
      yabai -m window --focus prev ||
      yabai -m window --focus last
    '';

    # shift-mod-j
    shortcut-move-next = ''
      yabai -m window --swap  next ||
      yabai -m window --swap  first
    '';

    # shift-mod-k
    shortcut-move-prev = ''
      yabai -m window --swap  prev ||
      yabai -m window --swap  last
    '';

    # Switch between displays, cycling around when we hit the end of list

    # mod-left
    shortcut-display-prev = ''
      yabai -m display --focus prev ||
      yabai -m display --focus last
    '';
    # mod-right
    shortcut-display-next = ''
      yabai -m display --focus next ||
      yabai -m display --focus first
    '';

    # General commands
    #"${       mod "f"    }" = "yabai -m window --toggle zoom-parent";

    # mod-r
    shortcut-force-rejig = ''
      shortcut-arrange-spaces
      pkill yabai || true
      sleep 2
      shortcut-fix-up-spaces
      pkill skhd || true
    '';

    # Tile/float the focused window
    # TODO: Add queries so they only do one or the other
    # "${       mod "t" }" = "yabai -m window --toggle float";
    # "${shift (mod "t")}" = "yabai -m window --toggle float";

    # Window resizing (emulates XMonad)
    # Vertical resizing is easy: just change where the bottom is
    # "${mod "i"}" = "yabai -m window --resize bottom:0:-60";
    # "${mod "o"}" = "yabai -m window --resize bottom:0:60";

    # Horizontal requires offset calculations
    # mod-h
    shortcut-resize-left = ''
      X=$(yabai -m query --windows --window | jq .frame.x)
      if [[ "$X" -lt 20 ]]
      then
        yabai -m window --resize right:-60:0
      else
        yabai -m window --resize left:-60:0
      fi
    '';
    # mod-l
    shortcut-resize-right = ''
      X=$(yabai -m query --windows --window | jq .frame.x)
      if [[ "$X" -lt 20 ]]
      then
        yabai -m window --resize right:60:0
      else
        yabai -m window --resize left:60:0
      fi
    '';

    # If our spaces aren't labelled, something is up
    shortcut-maybe-fix-spaces = ''
      if yabai -m query --spaces | jq -e 'map(.label) | sort | . != ${
        toJSON (map (n: "l${toString n}") spaces)
      }' > /dev/null
      then
        echo "Fixing up spaces first" 1>&2
        shortcut-fix-up-spaces
      fi
      true
    '';

    # Picks a display with more than 2 spaces (guaranteed since we have
    # fewer than 5 displays!)
    shortcut-pick-greedy-display = ''
      yabai -m query --displays |
        jq 'map(select(.spaces | length | . > 2)) | .[] | .index' |
        head -n1
    '';

    # Find a non-visible space from a display with many spaces
    shortcut-pick-invisible-space = ''
      D=$(shortcut-pick-greedy-display)
      yabai -m query --spaces --display "$D" |
        jq 'map(select(.visible | . == 0)) | .[] | .index' |
        head -n1
    '';

    # Make sure each display has at least two spaces, so we can move one
    shortcut-ensure-displays-have-spaces = ''
      # Loop through display indices which have fewer than 2 spaces
      while true
      do
        DS=$(yabai -m query --displays)
        echo "$DS" |
          jq -e 'map(select(.spaces | length | . < 2)) | . == []' > /dev/null &&
          break
        echo "$DS" |
          jq 'map(select(.spaces | length | . < 2)) | .[] | .index' |
          while read -r D
          do
            echo "Display $D is low on spaces, moving one over" 1>&2
            S=$(shortcut-pick-invisible-space)
            yabai -m space "$S" --display "$D" || true
            sleep 0.2
          done
      done
    '';

    # Get the focused display (the display of the focused space)
    shortcut-focused-display = ''
      yabai -m query --spaces |
        jq 'map(select(.focused | . == 1)) | .[] | .display'
    '';

    shortcut-force-space-focus = ''
        for RETRY in $(seq 1 10)
        do
          SPACES=$(yabai -m query --spaces)

          # Break if we're focused
          echo "$SPACES" | jq -e "${unwords [
            "map(select(.label == \\\"$1\\\")) |"
            ".[] | .focused == 0"
          ]}" > /dev/null || break

          # Move the desired space to the focused display
          D=$(shortcut-focused-display)
          if echo "$SPACES" | jq -e "${unwords [
               "map(select(.label == \\\"$1\\\")) |"
               ".[] | .display != $D"
             ]}" > /dev/null
          then
            echo "Moving $1 to display $D"
            yabai -m space $1 --display $D || true
            sleep 0.1

            # Restart the loop, to retry this step until it works
            continue
          fi

          # Focus this space
          yabai -m space --focus $1 || true
          sleep 0.1
        done
    '';
  } //

  # Switch to the labelled display
  listToAttrs (map (n: with { s = toString n; }; rec {
                     name  = "shortcut-switch-to-${s}";
                     value = wrap {
                       inherit name;
                       script = ''
                         #!/usr/bin/env bash
                         set -e
                         shortcut-maybe-fix-spaces
                         shortcut-ensure-displays-have-spaces
                         shortcut-force-space-focus l${s}
                       '';
                     };
                   })
                   spaces) //

          # Send focused window to a particular space (by label)
  listToAttrs (map (n: rec {
                     name  = "shortcut-move-to-${toString n}";
                     value = wrap {
                       inherit name;
                       script = ''
                         #!/usr/bin/env bash
                         set -e
                         yabai -m window --space l${toString n}
                       '';
                     };
                   })
                   spaces)
  ;
}
