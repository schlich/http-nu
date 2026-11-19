{
  description = "A Nushell-scriptable HTTP server";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      manifest = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package;
    in
    {
      packages = forAllSystems (
        pkgs:
        let
          inherit (pkgs) lib rustPlatform;
          http-nu = rustPlatform.buildRustPackage {
            pname = manifest.name;
            inherit (manifest) version;

            src = lib.fileset.toSource {
              root = ./.;
              fileset = lib.fileset.unions [
                ./Cargo.toml
                ./Cargo.lock
                ./build.rs
                ./src
                ./syntaxes
                ./examples/topic-placeholder.nu
                ./tests/test_plugin
              ];
            };
            cargoLock.lockFile = ./Cargo.lock;
            cargoBuildFlags = [
              "-p"
              "http-nu"
            ];

            nativeBuildInputs = [
              pkgs.pkg-config
            ]
            ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
              rustPlatform.bindgenHook
            ];
            buildInputs = with pkgs; [
              aws-lc
              libgit2
              oniguruma
              sqlite
            ];

            # The integration suite starts local servers. Run it in the existing CI job.
            doCheck = false;
            doInstallCheck = true;
            nativeInstallCheckInputs = [ pkgs.versionCheckHook ];
            versionCheckProgramArg = "--version";

            meta = {
              inherit (manifest) description homepage;
              license = lib.licenses.mit;
              mainProgram = "http-nu";
            };
          };
        in
        {
          default = http-nu;
          inherit http-nu;
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
