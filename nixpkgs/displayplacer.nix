{ fetchFromGitHub, stdenv }:

stdenv.mkDerivation {
  name = "displayplacer";
  src  = fetchFromGitHub {
    owner  = "jakehilborn";
    repo   = "displayplacer";
    rev    = "c9eb449";
    sha256 = "03i7r2rl9gv9n9qh4zw57hx0h2vi3lj2y1xkrbcxwwmxy23s0k5y";
  };
  installPhase = ''
    mkdir -p "$out/bin"
    cp displayplacer "$out/bin"
  '';
}
