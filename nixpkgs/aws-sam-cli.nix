# Fix aws-sam-cli dependencies. These originally broke when updating nixpkgs
# 20.09 to avoid a clang/linker problem on macOS Big Sur. Hopefully the next
# stable nixpkgs (21.03?) will have the Big Sur fix and a working aws-sam-cli!
{ aws-sam-cli, foldAttrs', isBroken, withDeps' }:
with rec {
  original = aws-sam-cli;
  patched  = original.overrideAttrs (old: {
    postPatch = old.postPatch + "\n" + foldAttrs'
      (name: { new, old }: result:
        result + " --replace \"${name}${old}\" \"${name}${new}\"")
      "substituteInPlace requirements/base.txt"
      {
        aws-sam-translator = { new = "~=1.31.0"; old = "==1.27.0"; };
        dateparser         = { new = "~=1.0"   ; old = "~=0.7"   ; };
        docker             = { new = "~=4.4"   ; old = "~=4.3.1" ; };
      };
  });
};
withDeps' original.name [ (isBroken original) ] patched
