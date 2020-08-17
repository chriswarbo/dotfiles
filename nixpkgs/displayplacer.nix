{ sources, stdenv }:

stdenv.mkDerivation {
  name         = "displayplacer";
  src          = sources.displayplacer.outPath;
  installPhase = ''
    mkdir -p "$out/bin"
    cp displayplacer "$out/bin"
  '';
}
