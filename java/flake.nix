{
  description = "Various utilities function for the Java Environment with Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    lib = {
      mkTrustStore =
        {
          pkgs,
          jdk,
          extraCerts ? [ ],
          storePassword ? "changeit",
        }:
        pkgs.stdenv.mkDerivation {
          name = "java-custom-truststore";

          srcs = extraCerts;
          nativeBuildInputs = [ jdk ];
          unpackPhase = "true";

          buildPhase = ''
            if [ -f "${jdk}/lib/openjdk/lib/security/cacerts" ]; then
              ORIGINAL_CACERTS="${jdk}/lib/openjdk/lib/security/cacerts"
            elif [ -f "${jdk}/lib/security/cacerts" ]; then
              ORIGINAL_CACERTS="${jdk}/lib/security/cacerts"
            else
              echo "Error:  Cacerts not found in the provided JDK." >&2
              exit 1
            fi

            cp "$ORIGINAL_CACERTS" ./cacerts
            chmod +w ./cacerts

            for cert in $srcs; do
              alias=$(basename "$cert" | sed 's/[^a-zA-Z0-9]/-/g')
              echo "Importing certificate : $cert (alias: $alias)"

              keytool -importcert \
                -noprompt \
                -keystore ./cacerts \
                -storepass "${storePassword}" \
                -alias "$alias" \
                -file "$cert"
            done
          '';

          installPhase = ''
            mkdir -p $out
            cp ./cacerts $out/cacerts
          '';
        };

      embedTrustStoreInJdk =
        {
          pkgs,
          jdk,
          trustStore,
        }:
        pkgs.symlinkJoin {
          name = "${jdk.name}-embedded-truststore";
          paths = [ jdk ];

          postBuild = ''
            CACERTS_REL_PATH=""
            if [ -f "$out/lib/openjdk/lib/security/cacerts" ]; then
              CACERTS_REL_PATH="lib/openjdk/lib/security/cacerts"
            elif [ -f "$out/lib/security/cacerts" ]; then
              CACERTS_REL_PATH="lib/security/cacerts"
            else
              echo "Error:  Cacerts not found in the provided JDK." >&2
              exit 1
            fi

            rm "$out/$CACERTS_REL_PATH"
            ln -s "${trustStore}/cacerts" "$out/$CACERTS_REL_PATH"
          '';
        };

      mkCustomJdk =
        {
          pkgs,
          jdk,
          extraCerts ? [ ],
          storePassword ? "changeit",
        }:
        let
          customTrustStore = self.lib.mkTrustStore {
            inherit
              pkgs
              jdk
              extraCerts
              storePassword
              ;
          };
        in
        self.lib.embedTrustStoreInJdk {
          inherit pkgs jdk;
          trustStore = customTrustStore;
        };
    };
  };
}
