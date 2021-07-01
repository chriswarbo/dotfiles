with { pkgs = import <nixpkgs> {}; };
pkgs.buildEnv {
  name             = "chrisw-packages";
  ignoreCollisions = true;
  paths            = (import <home/repos/nix-darwin> {
    configuration = ./darwin-configuration.nix;
  }).config.environment.systemPackages;
}
