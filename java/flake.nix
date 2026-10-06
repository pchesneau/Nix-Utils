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
        self.lib.wrapJdkWithTrustStore {
          inherit pkgs jdk;
          trustStore = customTrustStore;
        };

      wrapJdkWithTrustStore =
        {
          pkgs,
          jdk,
          trustStore,
          storePassword ? "changeit",
        }:
        pkgs.runCommand "${jdk.name}-wrapped-truststore"
          {
            nativeBuildInputs = [ pkgs.makeWrapper ];
          }
          ''
            mkdir -p $out
            cp -a ${jdk}/. $out/
            chmod -R u+w $out

            # The "java" launcher accepts JVM "-D" system properties directly on its
            # command line. Every other JDK tool (javac, jar, keytool, jlink, ...)
            # only recognizes its own options and instead forwards anything prefixed
            # with "-J" straight through to the underlying JVM, so the same "-D"
            # flags must be passed as "-J-D..." for those binaries.
            for bin in "$out"/bin/*; do
              [ -d "$bin" ] && continue
              [ -f "$bin" ] || [ -L "$bin" ] || continue

              name="$(basename "$bin")"
              hidden="$(dirname "$bin")/.$name-wrapped"
              mv "$bin" "$hidden"

              if [ "$name" = "java" ]; then
                flagPrefix=""
              else
                flagPrefix="-J"
              fi

              makeWrapper "$hidden" "$bin" \
                --add-flags "$flagPrefix-Djavax.net.ssl.trustStore=${trustStore}/cacerts" \
                --add-flags "$flagPrefix-Djavax.net.ssl.trustStorePassword=${storePassword}"
            done

            # symlinkJoin copies jdk's nix-support/setup-hook verbatim, which hardcodes
            # JAVA_HOME to the *original* (uncustomized) JDK store path. Regenerate it so
            # JAVA_HOME points at this derivation (with the wrapped binaries) instead.
            if [ -f "$out/nix-support/setup-hook" ]; then
              rm -f "$out/nix-support/setup-hook"
              cat > "$out/nix-support/setup-hook" <<HOOK
if [ -z "''${JAVA_HOME-}" ]; then export JAVA_HOME=$out; fi
HOOK
            fi
          '';
    };
  };
}
