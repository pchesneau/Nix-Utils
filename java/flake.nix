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
          jdk,
          extraCerts ? [],
          removedCertAliases ? []
        }:
        jdk.overrideAttrs (
          finalAttrs: old: {
            postInstall =
              old.postInstall
              + lib.concatStrings (
                lib.map (cert: ''
                  ${jdk}/bin/keytool -importcert -noprompt \
                    -keystore $out/lib/security/cacerts -storepass changeit \
                    -file ${cert}
                '') extraCerts
              )
              + lib.concatStrings (
                lib.map (cert: ''
                  ${jdk}/bin/keytool -delete -noprompt \
                    -keystore $out/lib/security/cacerts -storepass changeit \
                    -alias ${cert}
                '') removedCertAliases
              );

            doInstallCheck = false;
          }
        );
    };
  };
}
