# nix-utils-java

Nix utilities for customizing JDKs, most notably for injecting extra trusted
certificates into a JDK's `cacerts` truststore.

## Functions

### `lib.mkTrustStore`

Builds a custom `cacerts` truststore by copying the truststore from a given
`jdk` and importing extra certificates into it.

Arguments:
- `pkgs` — nixpkgs instance.
- `jdk` — the JDK derivation whose `cacerts` file is used as a base.
- `extraCerts` *(optional, default `[ ]`)* — list of certificate files (e.g.
  `.pem`) to import into the truststore.
- `storePassword` *(optional, default `"changeit"`)* — password used to open
  the truststore with `keytool`.

Returns a derivation whose output directory contains the resulting `cacerts`
file.

### `lib.embedTrustStoreInJdk`

Produces a copy of a JDK with its `cacerts` file replaced by a symlink to a
custom truststore.

Arguments:
- `pkgs` — nixpkgs instance.
- `jdk` — the JDK derivation to embed the truststore into.
- `trustStore` — a truststore derivation (e.g. the output of `mkTrustStore`)
  containing a `cacerts` file.

Returns a `symlinkJoin` derivation based on `jdk` with the truststore swapped
in.

### `lib.mkCustomJdk`

Convenience wrapper combining `mkTrustStore` and `embedTrustStoreInJdk` to
produce a JDK with additional trusted certificates in a single call.

Arguments:
- `pkgs` — nixpkgs instance.
- `jdk` — the JDK derivation to customize.
- `extraCerts` *(optional, default `[ ]`)* — list of certificate files to
  trust.
- `storePassword` *(optional, default `"changeit"`)* — truststore password.

Returns the customized JDK derivation.

## Example
````nix
{
  description = "A custom JDK with an additional trust in CACERTS";

  inputs = {
    # As of the day of making this sample, Graalvm-ce-musl in failing in nixpkgs/unstable
    nixpkgs.url = "github:NixOS/nixpkgs/6774f7bc253789b113a4f39285dc0fa100abeacc";

    nix-utils-java = {
        url = "github:pchesneau/Nix-Utils?dir=java";
        inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-utils-java }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};

          certA = ./your_custom_cert.pem;

        in
        {
          myCustomJdk = nix-utils-java.lib.mkCustomJdk {
            inherit pkgs;
            jdk = pkgs.graalvmPackages.graalvm-ce-musl; # The JDK you want to customize
            extraCerts = [ certA  ];
          };
          default = self.packages.${system}.myCustomJdk;
        }
      );
    };
}
````