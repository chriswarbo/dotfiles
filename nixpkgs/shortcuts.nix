# Commands to invoke when we press hot keys. These are mostly for controlling
# the Yabai window manager.
{ attrsToDirs', haskellPackages, lib, run, withDeps, wrap, writeScript }:

with builtins;
with lib;
with rec {
  # The spaces we're going to use. Always use these variables, instead
  # of hard-coding, to ensure consistency when changing the number.
  spaces    = range 1 9;  # Ignore 0 to avoid off-by-one nonsense
  count     = toString (length spaces);
  labels    = map (n: "l${toString n}") spaces;
  labelFile = writeScript "workspace-labels" (unlines labels);

  # Concatenate with spaces and newlines
  unlines = concatStringsSep "\n";
  unwords = concatStringsSep " ";

  # Consistent ways to log messages. Set DEBUG=1 for verbose information; errors
  # and info are always shown; fatal will also abort the current script.
  info  = str: ''echo "info: ${str}" 1>&2'';
  debug = str: ''[[ -z "$DEBUG" ]] || echo "debug: ${str}" 1>&2'';
  error = str: ''echo "error: ${str}" 1>&2'';
  fatal = str: error str + ''; echo "Fatal error, aborting" 1>&2; exit 1'';

  # All of our scripts use bash with stricter error checking
  makeScript = name: script: wrap {
    inherit name;
    script = ''
      #!/usr/bin/env bash
      set -e
      ${script}
    '';
  };

  # The commands we'll write out into the resulting package. This is defined as
  # a function taking a 'self' argument, so scripts can refer to other scripts.
  # This ensures infinite recursion is caught at build time, and makes sure we
  # don't mis-spell any of our commands.
  makeCommands = self: mapAttrs makeScript {
    # Common queries
    plugged-in = "[[ $(${haskellCommands.displayCount}) -gt 1 ]]";

    display-of-space = ''
      yabai -m query --spaces |
        jq --arg l "$1" 'map(select(.label == $l)) | .[] | .display'
    '';

    space-on-display = ''
      [[ $(${self.display-of-space} "$1") -eq "$2" ]]
    '';

    index-of-space = ''
      yabai -m query --spaces |
        jq --arg l "$1" 'map(select(.label == $l)) | .[] | .index'
    '';

    label-at-index = ''
      yabai -m query --spaces |
        jq --arg i "$1" 'map(select(.index == $i)) | .[] | .label'
    '';

    space-exists = ''
      yabai -m query --spaces |
        jq -e --arg l "$1" 'map(select(.label == $l)) | length | . > 0' \
        > /dev/null
    '';

    space-index-exists = ''
      yabai -m query --spaces |
        jq -e --arg i "$1" 'map(select(.index == $i)) | length | . > 0' \
        > /dev/null
    '';

    space-is-visible = ''
      yabai -m query --spaces |
        jq -e --arg l "$1" 'map(select(.label == $l)) | .[] | .visible == 1' \
        > /dev/null
    '';

    number-from-label = ''
      echo "$1" | grep -o '[0-9]*'
    '';

    space-has-index = ''
      [[ $(${self.index-of-space} "$1") -eq "$2" ]]
    '';

    space-index-matches = ''
      N=$(${self.number-from-label} "$1")
      ${self.space-has-index} "$1" "$N"
    '';

    space-of-window = ''
      I=$(yabai -m query --windows |
            jq --argjson w "$1" 'map(select(.id == $w)) | .[] | .space')
      yabai -m query --spaces |
        jq -r --argjson i "$I" 'map(select(.index == $i) | .label) | .[]'
    '';

    # Switch to displays and spaces. These are flaky, so we retry multiple times
    # and, if it keeps failing, we do some random switching around in the hope
    # that it un-sticks itself.

    focus-display = ''
      ${self.lax-spaces-are-set-up} focus-display

      ${debug "focus-display: Focusing $1"}
      COUNT=0
      [[ $(${haskellCommands.currentDisplay}) -eq $1 ]] ||
         ${haskellCommands.displayNext}
      sleep 0.2

      D=$(${haskellCommands.currentDisplay})
      if [[ "$D" -eq "$1" ]]
      then
        ${debug "focus-display: Switched focus to display $1"}
      else
        ${fatal "focus-display: Should be on $1, actually on $D"}
      fi
      exit 0
    '';

    focus-space = ''
      ${self.lax-spaces-are-set-up} focus-space

      if ! ${self.space-exists} "$1"
      then
        ${fatal "focus-space: Asked to focus space $1, which doesn't exist"}
      fi

      S1=$(${haskellCommands.currentSpace})
      ${debug "focus-space: We're on space $S1, asked to focus $1"}

      # Focus the display of the given space
      ${self.focus-display} "$(${self.display-of-space} "$1")"

      # Focus the given space, if it's not already
      COUNT=0
      while ! [[ "x$(${haskellCommands.currentSpace})" = "x$1" ]]
      do
        if [[ "$COUNT" -gt 30 ]]
        then
          ${fatal "focus-space: Couldn't get space $1 focused"}
        fi

        if [[ $(( COUNT % 10 )) -eq 9 ]]
        then
          ${haskellCommands.displayPrev}; sleep 0.2
          ${haskellCommands.displayNext}; sleep 0.2
        fi

        if [[ $(( COUNT % 15 )) -eq 4 ]]
        then
          yabai   -m space --focus next  2>/dev/null ||
            yabai -m space --focus first
        fi

        if [[ "$COUNT" -gt 3 ]]
        then
          R=$(${self.pick-existing-space})
          ${debug "focus-space: Struggling to focus; trying from $R"}
          yabai -m space --focus "$R"
          sleep 0.2
        fi

        ${debug "focus-space: $(${haskellCommands.currentSpace}) focused; focusing $1"}
        yabai -m space --focus "$1"
        sleep 0.2
        COUNT=$(( COUNT + 1 ))
      done

      S3=$(${haskellCommands.currentSpace})
      if [[ "x$S3" = "x$1" ]]
      then
        ${debug "focus-space: Successfully focused space $1"}
      else
        ${fatal "focus-space: Should've focused space $1, we're on $S3"}
      fi
      exit 0
    '';

    # Move spaces around, between displays and mission control index

    move-space-to-display = ''
      # Yabai only seems able to move the active space between displays. This
      # command will switch to the given space, move it to the given display,
      # then switch back to wherever we came from.
      ${self.spaces-are-set-up}

      ${debug "Seeing if space $1 is already on display $2"}
      D=$(${self.display-of-space} "$1")
      if [[ "$D" -eq "$2" ]]
      then
        ${debug "Nothing to do, $1 is already on $2, short-circuiting"}
        exit 0
      fi
      ${debug "Space $1 has display $D, we need to move it to $2"}

      ${debug "Making sure $1 is focused"}
      ${self.focus-space} "$1"

      C=$(${haskellCommands.currentSpace})
      if [[ "x$C" = "x$1" ]]
      then
        ${debug "Focused space $1, as we expected"}
      else
        ${fatal "We should have focused space $1, instead we have $C, aborting"}
      fi
      unset C

      ${debug "Sending space $1 to display $2"}
      yabai -m space --display "$2"; sleep 0.5

      D=$(${self.display-of-space} "$1")
      if [[ "$D" -eq "$2" ]]
      then
        ${debug "Space $1 now has display $2, like we wanted"}
      else
        ${fatal "Space $1 was meant to get display $2, actually has $D"}
      fi
      true
    '';

    shift-space-to-index = ''
      while [[ $(${self.index-of-space} "$1") -gt "$2" ]]
      do
        yabai -m space "$1" --move prev
      done
      while [[ $(${self.index-of-space} "$1") -lt "$2" ]]
      do
        yabai -m space "$1" --move next
      done
    '';

    # Set up our spaces how we want them

    find-unlabelled = ''
      # Spits out the indices of spaces which aren't labelled properly; either
      # because they're unlabelled, have a label we don't want, or have a
      # duplicate label

      # Assume we didn't find anything
      CODE=1

      SPACES=$(yabai -m query --spaces)

      # Note: 'label' is a keyword in jq
      UNLABELLED=$(echo "$SPACES" |
                   jq 'map(select(.label as $l       |${""
                                  } ${toJSON labels} |${""
                                  } map(. == $l)     |${""
                                  } any | not) | .index)')
      COUNT=$(echo "$UNLABELLED" | jq 'length')
      ${debug "There are $COUNT spaces which aren't labelled properly"}
      if [[ "$COUNT" -gt 0 ]]
      then
        CODE=0
        echo "$UNLABELLED" | jq '.[]'
      fi

      # Look for spaces with duplicate labels
      ${unlines
        (map (l: ''
               COUNT=$(echo "$SPACES" |
                       jq 'map(select(.label | . == ${toJSON l} )) | length')
               ${debug "Found $COUNT spaces with label ${l}"}
               if [[ "$COUNT" -gt 1 ]]
               then
                 # This label is applied to multiple spaces, spit
                 # out the index of one of them (arbitrarily)
                 I=$(echo "$SPACES" |
                     jq 'map(select(.label | . == ${toJSON l} )) |${""
                         }.[0] | .index')
                 ${debug "Too many spaces with label ${l}: $COUNT, should be 1"}
                 ${debug "Picked space index $I, out of those with label ${l}"}
                 CODE=0
               fi
             '')
             labels)}

      # Let other applications know if we found anything
      # Note that in normal operation we should only be called when
      # we need to find a space for a label, which implies that
      # there should be at least one available; hence the warning.
      if [[ "$CODE" -eq 0 ]]
      then
        ${debug "Found some unlabelled spaces, as we expected"}
      else
        ${error "Didn't find any unlabelled spaces; do we have enough?"}
      fi
      exit "$CODE"
    '';

    # Try to keep our spaces balanced across displays. This way, as we're
    # switching around between spaces, we won't end up trying to move the last
    # space off a display (which won't work)

    force-invisible-displays = ''
      # We want the first half of the spaces on display 1, the second on display
      # 2. This way, we should never run out of spaces on a display (e.g. when
      # we're asked to move a space to another display) and if/when things go
      # awry our labels should correspond more closely to the macOS indices.
      PRE="force-invisible-displays:"

      if ! ${self.plugged-in}
      then
        ${debug "$PRE Not plugged in to 1 monitor, skipping"}
        exit 0
      fi
      ${debug "$PRE Have 2 displays, forcing arrangement"}
      ${unwords (map (n: with { s = toString n; }; ''
                           if ${self.space-is-visible} "l${s}"
                           then
                             ${debug "$PRE Skipping visible space l${s}"}
                           else
                             ${debug "$PRE Forcing display of space l${s}"}
                             D=${if n <= (length spaces / 2) then "1" else "2"}
                             ${self.move-space-to-display} "l${s}" "$D"
                           fi
                     '')
                     spaces)}
    '';

    force-indices = ''
      # The spaces on a display should be in order of their labels, so if/when
      # something goes wrong there's little disruption to our window layouts.
      PRE="force-indices:"

      function shouldBeFirst {
        N=$(echo "$1" | grep -o '[0-9]*')
        [[ "$N" -le ${toString (length spaces / 2)} ]]
      }

      function shouldBeSecond {
        M=$(echo "$1" | grep -o '[0-9]*')
        [[ "$M" -le ${toString (length spaces / 2)} ]]
      }

      # There are two scenarios to handle
      VISIBLE1=$(yabai -m query --spaces |
                 jq -r 'map(select(.visible == 1) | select(.display == 1)) |${""
                        } .[] | .label')
      VISIBLE2=$(yabai -m query --spaces |
                 jq -r 'map(select(.visible == 1) | select(.display == 2)) |${""
                        } .[] | .label')

      if ${self.plugged-in}           &&
         ! shouldBeFirst  "$VISIBLE1" &&
         ! shouldBeSecond "$VISIBLE2"
      then
        ${debug "$PRE Scenario 1: Neither display shows their own space"}
        # This is easy enough: we swap the index locations of the visible spaces
        I1=$(${self.number-from-label} "$VISIBLE2")
        I2=$(${self.number-from-label} "$VISIBLE1")

        while true
        do
          MISPLACED=0
          for L in ${unwords labels}
          do
            I=$(${self.number-from-label} "$L")
            [[ "x$L" = "x$VISIBLE1" ]] && I="$I1"
            [[ "x$L" = "x$VISIBLE2" ]] && I="$I2"
            if ! ${self.space-has-index} "$L" "$I"
            then
              MISPLACED=1
              ${self.shift-space-to-index} "$L" "$I"
            fi
          done
          if [[ "$MISPLACED" -eq 0 ]]
          then
            ${debug "$PRE All spaces at the correct index"}
            break
          fi
        done
        exit 0
      fi

      ${debug "$PRE Scenario 2: Spaces should be in numerical order"}
      for D in 1 2
      do
        ${debug "$PRE Sorting spaces on display $D"}
        # Sorting by index should be the same as by label; otherwise we need to
        # do some rearranging.
        # If a display isn't plugged in, its spaces will be [] which will match
        # both sorting methods.
        while yabai -m query --spaces |
              jq -e --argjson d "$D" 'map(select(.display == $d))     | ${""
                                      } sort_by(.index) | map(.label) | ${""
                                      } . as $raw | $raw | debug | sort | . != $raw' \
              > /dev/null
        do
          ${debug "$PRE Picking two spaces to try and swap"}

          SPACES=$(yabai -m query --spaces |
                   jq -r --argjson d "$D" \
                      'map(select(.display == $d) | .label) | .[]')
          ${debug "$PRE SPACES: $SPACES"}
          PAIR=$(echo "$SPACES" | shuf | head -n2 | sort)
          ${debug "$PRE PAIR: $PAIR"}

          S1=$(echo "$PAIR" | head -n1)
          S2=$(echo "$PAIR" | tac | head -n1)

          I1=$(${self.index-of-space} "$S1")
          I2=$(${self.index-of-space} "$S2")
          if [[ "$I1" -gt "$I2" ]]
          then
            ${debug "$PRE Space $S1 ($I1) should appear before $S2 ($I2)"}
            ${self.focus-space} "$S1"
            yabai -m space --move next
          else
            ${debug "$PRE Space $S1 ($I1) appears before $S2 ($I2)"}
          fi
        done
      done
      exit 0
    '';

    # General commands
    #"${       mod "f"    }" = "yabai -m window --toggle zoom-parent";

    fix-up-emacs = ''
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

    # Tile/float the focused window
    # TODO: Add queries so they only do one or the other
    # "${       mod "t" }" = "yabai -m window --toggle float";
    # "${shift (mod "t")}" = "yabai -m window --toggle float";

    # Window resizing (emulates XMonad)
    # Vertical resizing is easy: just change where the bottom is
    shrink-vert = "yabai -m window --resize bottom:0:-60";
    grow-vert   = "yabai -m window --resize bottom:0:60";

    # Horizontal requires offset calculations
    shrink-horiz = ''
      X=$(yabai -m query --windows --window | jq .frame.x)
      if [[ "$X" -lt 20 ]]
      then
        yabai -m window --resize right:-60:0
      else
        yabai -m window --resize left:-60:0
      fi
    '';
    grow-horiz = ''
      X=$(yabai -m query --windows --window | jq .frame.x)
      if [[ "$X" -lt 20 ]]
      then
        yabai -m window --resize right:60:0
      else
        yabai -m window --resize left:60:0
      fi
    '';

    spaces-are-set-up = ''
      if yabai -m query --spaces | jq -e 'map(.label) | sort | . != ${
        toJSON (map (n: "l${toString n}") spaces)
      }' > /dev/null
      then
        ${debug "spaces-are-set-up: Spaces aren't set up properly"}
        exit 1
      fi
      ${debug "spaces-are-set-up: Spaces are set up properly"}
      exit 0
    '';

    lax-spaces-are-set-up = ''
      # Check if spaces are set up, unless LAX is set. This lets us avoid checks
      # when doing the actual setup, whilst still doing them by default after.
      if [[ -z "$LAX" ]] && ! ${self.spaces-are-set-up}
      then
        ${fatal "$1: Spaces aren't set up"}
      fi
      exit 0
    '';

    # Picks a display with more than 2 spaces (guaranteed since we have
    # fewer than 5 displays!)
    pick-greedy-display = ''
      yabai -m query --displays |
        jq 'map(select(.spaces | length | . > 2)) | .[] | .index' |
        head -n1
    '';

    # Find a non-visible space from a display with many spaces
    pick-invisible-space = ''
      D=$(${self.pick-greedy-display})
      yabai -m query --spaces --display "$D" |
        jq 'map(select(.visible | . == 0)) | .[] | .index' |
        head -n1
    '';

    # Make sure each display has at least two spaces, so we can move one
    ensure-displays-have-spaces = ''
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
            S=$(${self.pick-invisible-space})
            yabai -m space "$S" --display "$D" || true
            sleep 0.2
          done
      done
    '';

    # Get the focused display (the display of the focused space)
    focused-display = ''
      yabai -m query --spaces |
        jq 'map(select(.focused | . == 1)) | .[] | .display'
    '';

    force-space-focus = ''
        for RETRY in $(seq 1 10)
        do
          SPACES=$(yabai -m query --spaces)

          # Break if we're focused
          echo "$SPACES" | jq -e "${unwords [
            "map(select(.label == \\\"$1\\\")) |"
            ".[] | .focused == 0"
          ]}" > /dev/null || break

          # Move the desired space to the focused display
          D=$(${self.focused-display})
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

    # Switch to the space with the given label. Make sure it exists first, and
    # bring it to the current display if it isn't already.
    switch-to = ''
      LABEL="$1" ${haskellCommands.focusHereEnv}
    '';

    move-window  = ''
      D=$(${haskellCommands.currentDisplay})
      yabai -m window  --space "$1"; sleep 0.1
      yabai -m display --focus "$D"
    '';

    close-window = ''yabai -m window --close       '';
    make-main    = ''yabai -m window --swap   west '';
    toggle-split = ''yabai -m window --toggle split'';

    pick-existing-space = ''
      yabai -m query --spaces | jq -r 'map(.label) | .[]' |
        shuf | head -n1
    '';

    pick-array-elements = ''
      COUNT=1
      [[ -z "$1" ]] || COUNT="$1"
      jq -r '.' | shuf | head -n"$COUNT"
    '';

    # Tests. These aren't meant to be bound to anything, but are useful to run
    # manually (if you don't mind your spaces getting messed around!)
    run-tests = ''
      CODE=0

      function go {
        ${debug "RUNNING: $1"}
        if "$2"
        then
          ${debug "PASS: $1"}
        else
          CODE=1
          ${error "FAIL: $1"}
        fi
      }

      ${haskellCommands.labelSpaces}

      ${debug "Running tests"}
      ${unlines (map ({name, script}: ''
                       go '${name}' '${makeScript name script}'
                     '')
        (with rec {
          pick-window = makeScript "pick-window" ''
            yabai -m query --windows | jq -r 'map(.id) | .[]' | shuf | head -n1
          '';

          pick-correct-label = makeScript "pick-correct-label" ''
            shuf < ${labelFile} | head -n1
          '';
        };
        # We use this list format, rather than an attrset, to enforce the order.
        # This lets us put simpler tests first.
        [
          {
            name   = "focus-display";
            script = ''
              ${self.plugged-in} || exit 0
              for N in $(seq 1 5)
              do
                D=$(( (RANDOM % 2) + 1 ))
                ${self.focus-display} "$D"
              done
              exit 0
            '';
          }
          {
            name   = "focus-space";
            script = ''
              for N in $(seq 1 10)
              do
                L=$(${self.pick-existing-space})
                ${self.focus-space} "$L"
                ON=$(${haskellCommands.currentSpace})
                if [[ "x$ON" = "x$L" ]]
                then
                  ${debug "Focused space $L successfully"}
                else
                  D=$(${self.display-of-space} "$L")
                  D2=$(${haskellCommands.currentDisplay})
                  ${fatal "Failed to focus space $L ($D); we're on $ON ($D2)"}
                fi
              done
            '';
          }
          {
            name   = "space-of-window";
            script = ''
              SPACES=()
              while read -r I
              do
                SPACES+=( $I )
              done < <(yabai -m query --spaces | jq 'map(.index) | .[]')

              ${debug "Found spaces ${"$"}{SPACES[@]}"}
              for I in ${"$"}{SPACES[@]}
              do
                ${debug "Trying on space $I"}
                L=$(yabai -m query --spaces |
                    jq -r --argjson i "$I" \
                       'map(select(.index == $i) | .label) | .[]')
                yabai -m query --windows |
                  jq --argjson i "$I" 'map(select(.space == $i) | .id) | .[]' |
                  while read -r W
                  do
                    S=$(${self.space-of-window} "$W")
                    if [[ "x$S" = "x$L" ]]
                    then
                      ${debug "Window $W was found to be from space $L"}
                    else
                      ${fatal "Window $W is from $L, not $S"}
                    fi
                  done
              done
            '';
          }
          {
            name   = "spaces-are-set-up";
            script = ''
              CODE=0
              FOUND=$(yabai -m query --spaces | jq 'length')
              if [[ "$FOUND" -ne ${count} ]]
              then
                ${error "Should have ${count} spaces, actually have $COUNT"}
                CODE=1
              fi

              for L in ${unwords labels}
              do
                FOUND=$(yabai -m query --spaces |
                        jq --arg l "$L" 'map(select(.label == $l)) | length')
                if [[ "$FOUND" -ne 1 ]]
                then
                  ${error "Found $FOUND spaces with label $L"}
                  CODE=1
                fi
              done
              exit $CODE
            '';
          }
          {
            name   = "displays-have-spaces";
            script = ''
              if ! ${self.plugged-in}
              then
                ${info "Only 1 display, skipping test displays-have-spaces"}
                exit 0
              fi

              ${self.ensure-displays-have-spaces}
            '';
          }
          {
            name   = "move-window";
            script = ''
              CODE=0

              CWINDOW=$(${haskellCommands.currentWindow})
               CSPACE=$(${self.space-of-window} "$CWINDOW")
              ${debug "Focused on window $CWINDOW on space $CSPACE"}
              C=$(${haskellCommands.currentSpace})
              if ! [[ "x$CSPACE" = "x$C" ]]
              then
                ${fatal "current-space gave $C, space-of-window gave $CSPACE"}
              fi

              ${debug "Picking a random window and space"}
              W=$(${pick-window})
              TO=$(${self.pick-existing-space})

              ${debug "Focusing space of window $W"}
              FROM=$(${self.space-of-window} "$W")
              ${self.focus-space} "$FROM"
              ON=$(${haskellCommands.currentSpace})
              if [[ "x$ON" = "x$FROM" ]]
              then
                ${debug "We switched to space $ON, for window $W, as expected"}
              else
                ${debug "We should have switched to space $FROM, but we're on $ON"}
                ${fatal "move-window test setup failed, aborting"}
              fi
              yabai -m window --focus "$W"
              ${self.move-window} "$TO"

              OURSPACE=$(${haskellCommands.currentSpace})
              if [[ "x$OURSPACE" = "x$FROM" ]]
              then
                ${debug "Moving windows doesn't change our space, as expected"}
              else
                ${error "On space $ON, should still be on $OURSPACE"}
                CODE=1
              fi

              NEWSPACE=$(${self.space-of-window} "$W")
              if [[ "x$NEWSPACE" = "x$TO" ]]
              then
                ${debug "Window $W was sent to space $TO as it should"}
              else
                ${error "Window $W is on space $NEWSPACE, but it was sent to $TO"}
                CODE=1
              fi

              exit $CODE
            '';
          }
          {
            name   = "switch-to";
            script = ''
              CODE=0
              START=$(${haskellCommands.currentSpace})
              ALL=$(echo -e '${concatStringsSep "\\n" labels}')
              for REPEAT in $(seq 1 10)
              do
                TO=$(echo "$ALL" | shuf | head -n1)
                ${self.switch-to} "$TO"
                ON=$(${haskellCommands.currentSpace})
                if ! [[ "x$ON" = "x$TO" ]]
                then
                  ${error "Tried to switch to '$TO', ended up on '$ON'"}
                  CODE=1
                fi
              done
              ${self.switch-to} "$START"
              exit "$CODE"
            '';
          }
        ]))}

      ${debug "Finished tests. Restoring spaces."}
      restore

      if [[ "$CODE" -eq 0 ]]
      then
        ${debug "ALL TESTS PASSED"}
      else
        ${debug "SOME TESTS FAILED"}
      fi
      exit $CODE
    '';
  };

  # Tie the knot, so 'self' works
  shellCommands = makeCommands shellCommands;

  haskellShortcut =
    with rec {
      deps = extra: haskellPackages.ghcWithPackages (h: [
        h.aeson h.polysemy h.process-extras
      ] ++ map (p: getAttr p h) extra);

      mkScript = name: writeScript "haskell-shortcut-${name}.hs" ''
        module Main where
        import Yabai
        main = mkMain ${name}
      '';

      compile = extra: n: main: run {
        name   = "haskell-shortcut-${n}";
        paths  = [ (deps extra) ];
        vars   = { inherit main; };
        script = ''
          #!/usr/bin/env bash
          set -e
          cp "${./Yabai.hs}" Yabai.hs
          sed -e 's/undefined -- LABELS_GO_HERE/${toJSON labels}/g' -i Yabai.hs
          cp "$main" Main.hs
          ghc --make Main.hs -o "$out"
        '';
      };

      tests = run {
        name   = "YabaiTests";
        vars   = {
          tests = compile
            [ "lens" "QuickCheck" "tasty" "tasty-quickcheck" ]
            "tests"
            ./YabaiTests.hs;
        };
        script = ''"$tests" && mkdir "$out"'';
      };
    };
    name: withDeps [ /*tests*/ ]
                   (compile [] name (mkScript name));

  haskellCommands = genAttrs [
    "currentDisplay"
    "currentSpace"
    "currentWindow"
    "displayCount"
    "displayNext"
    "displayPrev"
    "focusHereEnv"
    "labelSpaces"
    "nextWindow"
    "moveWindowNext"
    "moveWindowPrev"
    "prevWindow"
  ] haskellShortcut;
};
rec {
  inherit spaces;
  commands = shellCommands // haskellCommands;

  # Make the commands available as a package, so we can invoke them manually
  package = attrsToDirs' "shortcuts" {
    bin = { shortcuts = commands; };
  };
}
