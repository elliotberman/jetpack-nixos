{ lib
, stdenv
, stdenvNoCC
, callPackage
, buildPackages
, pkgsCross
, fetchFromGitHub
, fetchurl
, fetchpatch
, runCommand
, edk2
, acpica-tools
, dtc
, python3
, bc
, imagemagick
, unixtools
, libuuid
, which
, nasm
, findutils
, applyPatches
, nukeReferences
, l4tVersion
, # Optional path to a boot logo that will be converted and cropped into the format required
  bootLogo ? null
, # Patches to apply to edk2-nvidia source tree
  edk2NvidiaPatches ? [ ]
, # Patches to apply to edk2 source tree
  edk2UefiPatches ? [ ]
, debugMode ? false
, errorLevelInfo ? debugMode
, # Enables a bunch more info messages

  # The root certificate (in PEM format) for authenticating capsule updates. By
  # default, EDK2 authenticates using a test keypair commited upstream.
  trustedPublicCertPemFile ? null
}:

let
  # TODO: Move this generation out of uefi-firmware.nix, because this .nix
  # file is callPackage'd using an aarch64 version of nixpkgs, and we don't
  # want to have to recompilie imagemagick
  bootLogoVariants = runCommand "uefi-bootlogo" { nativeBuildInputs = [ buildPackages.buildPackages.imagemagick ]; } ''
    mkdir -p $out
    convert ${bootLogo} -resize 1920x1080 -gravity Center -extent 1920x1080 -format bmp -define bmp:format=bmp3 $out/logo1080.bmp
    convert ${bootLogo} -resize 1280x720  -gravity Center -extent 1280x720  -format bmp -define bmp:format=bmp3 $out/logo720.bmp
    convert ${bootLogo} -resize 640x480   -gravity Center -extent 640x480   -format bmp -define bmp:format=bmp3 $out/logo480.bmp
  '';

  ###

  # See: https://github.com/NVIDIA/edk2-edkrepo-manifest/blob/main/edk2-nvidia/Platform/NVIDIAPlatformsManifest.xml
  edk2-src = (fetchFromGitHub rec {
    owner = "NVIDIA";
    repo = "edk2";
    name = repo;
    rev = "r${l4tVersion}";
    fetchSubmodules = true;
    sha256 = "sha256-TBroMmFyZt6ypooDtSzScjA3POPr76rJKfLQfAkRwdU=";
  }).overrideAttrs
    # see https://github.com/NixOS/nixpkgs/pull/354193
    (_: {
      env = {
        GIT_CONFIG_COUNT = 1;
        GIT_CONFIG_KEY_0 = "url.https://github.com/tianocore/edk2-subhook.git.insteadOf";
        GIT_CONFIG_VALUE_0 = "https://github.com/Zeex/subhook.git";
      };
    });

  edk2-platforms = fetchFromGitHub rec {
    owner = "NVIDIA";
    repo = "edk2-platforms";
    name = repo;
    rev = "r${l4tVersion}";
    sha256 = "sha256-27dKEi66UWBgJi3Sb2/naeeSC2CJ5+Dbtw8e0o5Y/Hg=";
  };

  edk2-non-osi = fetchFromGitHub rec {
    owner = "NVIDIA";
    repo = "edk2-non-osi";
    name = repo;
    rev = "r${l4tVersion}";
    sha256 = "sha256-FnznH8KsB3rD7sL5Lx2GuQZRPZ+uqAYqenjk+7x89mE=";
  };

  edk2-nvidia = applyPatches {
    name = "edk2-nvidia";
    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "edk2-nvidia";
      rev = "r${l4tVersion}";
      sha256 = "sha256-Ri+0vrxvd7eE7TP/KBM0ET2jX0fupdC3+Dli+IshUP8=";
    };
    patches = edk2NvidiaPatches ++ [
      # Fix Eqos driver to use correct TX clock name
      # PR: https://github.com/NVIDIA/edk2-nvidia/pull/76
      (fetchpatch {
        url = "https://github.com/NVIDIA/edk2-nvidia/commit/26f50dc3f0f041d20352d1656851c77f43c7238e.patch";
        hash = "sha256-cc+eGLFHZ6JQQix1VWe/UOkGunAzPb8jM9SXa9ScIn8=";
      })

      ./stuart-passthru-compiler-prefix.diff

      # ./capsule-authentication.patch

      # Have UEFI use the device tree compiled into the firmware, instead of
      # using one from the kernel-dtb partition.
      # See: https://github.com/anduril/jetpack-nixos/pull/18
      # ./edk2-uefi-dtb.patch
    ];
    postPatch = lib.optionalString errorLevelInfo ''
      sed -i 's#PcdDebugPrintErrorLevel|.*#PcdDebugPrintErrorLevel|0x8000004F#' Platform/NVIDIA/NVIDIA.common.dsc.inc
    '' + lib.optionalString (bootLogo != null) ''
      cp ${bootLogoVariants}/logo1080.bmp Silicon/NVIDIA/Assets/nvidiagray1080.bmp
      cp ${bootLogoVariants}/logo720.bmp Silicon/NVIDIA/Assets/nvidiagray720.bmp
      cp ${bootLogoVariants}/logo480.bmp Silicon/NVIDIA/Assets/nvidiagray480.bmp
    '';
  };

  edk2-nvidia-non-osi = fetchFromGitHub rec {
    owner = "NVIDIA";
    repo = "edk2-nvidia-non-osi";
    name = repo;
    rev = "r${l4tVersion}";
    sha256 = "sha256-qQs1jO/h6+j9WLfz1OtYpgZutEeX284BlcUKJWvghEE=";
  };

  edk2-jetson = edk2.overrideAttrs (prev: {
    # Upstream nixpkgs patch to use nixpkgs OpenSSL
    # See https://github.com/NixOS/nixpkgs/blob/44733514b72e732bd49f5511bd0203dea9b9a434/pkgs/development/compilers/edk2/default.nix#L57
    src = runCommand "edk2-unvendored-src" { } ''
      cp --no-preserve=mode -r ${edk2-src} $out
      rm -rf $out/CryptoPkg/Library/OpensslLib/openssl
      mkdir -p $out/CryptoPkg/Library/OpensslLib/openssl
      tar --strip-components=1 -xf ${buildPackages.openssl.src} -C $out/CryptoPkg/Library/OpensslLib/openssl
      chmod -R +w $out/
      # Fix missing INT64_MAX include that edk2 explicitly does not provide
      # via it's own <stdint.h>. Let's pull in openssl's definition instead:
      sed -i $out/CryptoPkg/Library/OpensslLib/openssl/crypto/property/property_parse.c \
      -e '1i #include "internal/numbers.h"'
    '';

    depsBuildBuild = prev.depsBuildBuild ++ [ libuuid ];
  });

  pythonEnv = buildPackages.python312.withPackages (ps: callPackage ./pyenv.nix { inherit ps edk2-nvidia; });

  toolchain =
    (pkgsCross.aarch64-multiplatform.stdenv.cc.overrideAttrs (prev: {
      # https://github.com/NVIDIA/edk2-nvidia/wiki/Build-without-docker
      # asks us to install gcc-ar, gcc-nm, and gcc-ranlib & edk2 expects at least gcc-ar
      # stdenv.cc doesn't have these by default, so install them too
      installPhase = (prev.installPhase or "") + ''
        for binary in gcc-ar gcc-nm gcc-ranlib; do
          if [ -e $ccPath/${prev.passthru.targetPrefix}$binary ]; then
            ln -s $ccPath/${prev.passthru.targetPrefix}$binary $out/bin/${prev.passthru.targetPrefix}$binary
          fi
        done
      '';
    }));

  buildTarget = if debugMode then "DEBUG" else "RELEASE";

  jetson-edk2-uefi =
    # TODO: edk2.mkDerivation doesn't have a way to override the edk version used!
    # Make it not via passthru ?
    stdenv.mkDerivation (finalAttrs: {
      pname = "jetson-edk2-uefi";
      version = l4tVersion;

      srcs = [
        edk2-src
        edk2-platforms
        edk2-non-osi
        edk2-nvidia
        edk2-nvidia-non-osi
      ];

      sourceRoot = ".";

      depsBuildBuild = [ buildPackages.stdenv.cc libuuid ];
      nativeBuildInputs = [
        pythonEnv
        toolchain

        # from nixpkgs
        acpica-tools
        dtc
        nasm
        unixtools.whereis
        which
      ];
      # stuart (nvidia extensions) really wants CROSS_COMPILER_PREFIX to look like this
      CROSS_COMPILER_PREFIX = "${toolchain}/bin/${toolchain.targetPrefix}";
      # DANGER: If someone else modifies PYTHONPATH, then we lose this
      # We're okay when this was written.
      PYTHONPATH = "${edk2-nvidia}/Silicon/NVIDIA";

      # see nixpkgs/pkgs/by-name/ed/edk2/package.nix
      hardeningDisable = [
        "format"
        "fortify"
      ];

      prePatch = ''
        rm -rf edk2/BaseTools
        cp -r ${edk2-jetson}/BaseTools edk2/BaseTools
        chmod -R u+w edk2/BaseTools
      '';

      patchPhase = ''
        ${findutils}/bin/find . -name \*_ext_dep.yaml -delete
        patchShebangs .
      '';

      configurePhase = ''
        runHook preConfigure

        ${lib.optionalString (trustedPublicCertPemFile != null) ''
        echo Using ${trustedPublicCertPemFile} as public certificate for capsule verification
        ${lib.getExe buildPackages.openssl} x509 -outform DER -in ${trustedPublicCertPemFile} -out edk2/PublicCapsuleKey.cer
        python3 edk2/BaseTools/Scripts/BinToPcd.py -p gEfiSecurityPkgTokenSpaceGuid.PcdPkcs7CertBuffer -i edk2/PublicCapsuleKey.cer -o edk2/PublicCapsuleKey.cer.gEfiSecurityPkgTokenSpaceGuid.PcdPkcs7CertBuffer.inc
        python3 edk2/BaseTools/Scripts/BinToPcd.py -x -p gFmpDevicePkgTokenSpaceGuid.PcdFmpDevicePkcs7CertBufferXdr -i edk2/PublicCapsuleKey.cer -o edk2/PublicCapsuleKey.cer.gFmpDevicePkgTokenSpaceGuid.PcdFmpDevicePkcs7CertBufferXdr.inc
        ''}

        runHook postConfigure
      '';

      buildPhase = ''
        export WORKSPACE=$(pwd)
        python edk2/BaseTools/Edk2ToolsBuild.py -t GCC5
        stuart_setup -c edk2-nvidia/Platform/NVIDIA/Jetson/PlatformBuild.py
        stuart_build -c edk2-nvidia/Platform/NVIDIA/Jetson/PlatformBuild.py --target ${buildTarget}
      '';

      installPhase = ''
        runHook preInstall
        mv -v Build/*/* $out
        runHook postInstall
      '';
    });

  uefi-firmware = runCommand "uefi-firmware-${l4tVersion}"
    {
      nativeBuildInputs = [ python3 nukeReferences ];
    }
    ''
      mkdir -p $out
      python3 ${edk2-nvidia}/Silicon/NVIDIA/edk2nv/FormatUefiBinary.py \
        ${jetson-edk2-uefi}/FV/UEFI_NS.Fv \
        $out/uefi_jetson.bin

      python3 ${edk2-nvidia}/Silicon/NVIDIA/edk2nv/FormatUefiBinary.py \
        ${jetson-edk2-uefi}/AARCH64/L4TLauncher.efi \
        $out/L4TLauncher.efi

      mkdir -p $out/dtbs
      for filename in ${jetson-edk2-uefi}/AARCH64/Silicon/NVIDIA/Tegra/DeviceTree/DeviceTree/OUTPUT/*.dtb; do
        cp $filename $out/dtbs/$(basename "$filename" ".dtb").dtbo
      done

      # Get rid of any string references to source(s)
      nuke-refs $out/uefi_jetson.bin
    '';
in
{
  inherit edk2-jetson uefi-firmware;
}


