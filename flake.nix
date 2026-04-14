{
  description = "fht-compositor optimized for MT8183 Chromebooks (Zinux/Burnet)";

  inputs = {
    fht-source = {
      url = "github:nferhat/fht-compositor";
      flake = false; 
    };
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, nixpkgs, fht-source, rust-overlay, ... }:
    let
      system = "aarch64-linux";
      overlays = [ (import rust-overlay) ];
      pkgs = import nixpkgs { inherit system overlays; };
      
      rust-toolchain = pkgs.rust-bin.stable.latest.default;

      fht-bin = pkgs.rustPlatform.buildRustPackage {
        pname = "fht-compositor";
        version = "25.10.1";
        src = fht-source;

	postPatch = ''
          substituteInPlace src/backend/udev/mode.rs \
            --replace "name," "name: unsafe { std::mem::transmute(name) },"
        '';

        cargoLock = {
          lockFile = "${fht-source}/Cargo.lock";
          # This is what fixed your error. Nix needs to verify the git-based sub-dependencies.
          outputHashes = {
            "fht-animation-0.1.0" = "sha256-P+KGfcjwjuxAXZ+UGhPL0TStOLIOfAH0p5gX2sqjyMw=";
            "smithay-0.7.0" = "sha256-mUyAtCAkkDqyOvg0D1vEFs42AdAESPQCMs1Ls6x9ZJU=";
            "libspa-0.9.2" = "sha256-CKVuofGwnFwbHLNy1kDdpbF1fIeyhH7NFHp8cHhxjI8=";
            "pipewire-0.9.2" = "sha256-CKVuofGwnFwbHLNy1kDdpbF1fIeyhH7NFHp8cHhxjI8=";
            "smithay-drm-extras-0.1.0" = "sha256-mUyAtCAkkDqyOvg0D1vEFs42AdAESPQCMs1Ls6x9ZJU=";
          };
        };

        nativeBuildInputs = [ 
          pkgs.pkg-config 
          rust-toolchain
          pkgs.cmake
	  pkgs.clang
        ];

        buildInputs = [
          pkgs.wayland
          pkgs.libinput
          pkgs.libxkbcommon
          pkgs.pixman
          pkgs.udev
          pkgs.mesa
          pkgs.libgbm
          pkgs.pango
          pkgs.fontconfig
	  pkgs.seatd
	  pkgs.pipewire
	  pkgs.libdrm
	  pkgs.libdisplay-info
	  pkgs.libxml2
	  pkgs.systemd
        ];

	LIBCLANG_PATH = "${pkgs.libclang.lib}/lib";

        STRICT_WLROOTS = "0"; 
      };

    in {
      packages.${system}.default = pkgs.symlinkJoin {
        name = "fht-compositor-burnet";
        paths = [ fht-bin ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/fht-compositor \
            --set WLR_RENDERER gles2 \
            --set WLR_NO_HARDWARE_CURSORS 1 \
            --set SMITHAY_USE_GLES2 1 \
            --set BRIDGE_PATH "$HOME/.local/share/nix-burnet-bridge" \
            --prefix LD_LIBRARY_PATH : "$HOME/.local/share/nix-burnet-bridge:/usr/lib/aarch64-linux-gnu" \
            --set __EGL_VENDOR_LIBRARY_FILENAMES "/usr/share/glvnd/egl_vendor.d/50_mesa.json"
        '';
      };

      devShells.${system}.default = pkgs.mkShell {
        inputsFrom = [ fht-bin ];
        shellHook = ''
          source /etc/nix-hardware/burnet.env
          echo "Burnet Hardware Bridge Active"
        '';
      };
    };
}
