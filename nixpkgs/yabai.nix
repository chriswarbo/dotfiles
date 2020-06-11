# Yabai is a tiling window manager, which will resize and arrange our windows
# automatically. This makes full use of the whole screen(s), ensures nothing is
# obscured by overlapping, and means we don't have to care about window position
# and size again.
# Note that Yabai works on top of the macOS window manager, so the title bars,
# minimise/maximise/close buttons, etc. will all continue to work as normal.
# Also note that Yabai is controlled by sending it commands, both as "config"
# and for interaction; we define a shell script here for the former, and set up
# keybindings for the latter in skhd.nix
{ config, pkgs }:
{
  enable                  = true;
  enableScriptingAddition = true;
  package                 = pkgs.yabai;
  config                  = {
    # global settings
    active_window_border_color   = "0xff5c7e81";
    active_window_border_topmost = "off";
    active_window_opacity        = "1.0";
    auto_balance                 = "on";
    focus_follows_mouse          = "autoraise";
    insert_window_border_color   = "0xffd75f5f";
    mouse_action1                = "move";
    mouse_action2                = "resize";
    mouse_follows_focus          = "off";
    mouse_modifier               = "alt";
    normal_window_border_color   = "0xff505050";
    normal_window_opacity        = "1.0";
    split_ratio                  = "0.50";
    status_bar                   = "off";
    window_border                = "on";
    window_border_placement      = "inset";
    window_border_radius         = "3";
    window_border_width          = "2";
    window_opacity               = "off";
    window_opacity_duration      = "0.0";
    window_placement             = "second_child";
    window_shadow                = "off";
    window_topmost               = "on";

    # general space settings
    layout         = "bsp";
    window_gap     = "0";
       top_padding = "0";
    bottom_padding = "0";
      left_padding = "0";
     right_padding = "0";
  };
}
