{
  description = "Various utilities function for the Java Environment with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    lib = {
      mkCustomJvm =
        {
          lib,
          graalvm,
          extraCerts,
        }:
        graalvm.overrideAttrs (
          finalAttrs: old: {
            postInstall =
              old.postInstall
              + lib.concatStrings (
                lib.map (cert: ''
                  ${graalvm}/bin/keytool -importcert -noprompt \
                    -keystore $out/lib/security/cacerts -storepass changeit \
                    -file ${cert}
                '') extraCerts
              );

            doInstallCheck = false;
          }
        );
    };
  };
}
