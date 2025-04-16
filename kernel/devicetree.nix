{ bspSrc
, gitRepos
, kernel
, l4tVersion
, lib
, runCommand
, stdenv
, ...
}:
let
  l4t-devicetree-sources = runCommand "l4t-devicetree-sources" { }
    (lib.strings.concatStrings
      ([ "mkdir -p $out ; cp ${bspSrc}/source/Makefile $out/Makefile ;" ] ++
        (lib.lists.forEach
          [ "hardware/nvidia/t23x/nv-public" "hardware/nvidia/tegra/nv-public" "kernel-devicetree" ]
          (
            project:
            ''
              mkdir -p $out/${project}
              cp --no-preserve=all -r ${lib.attrsets.attrByPath [project] 0 gitRepos}/. $out/${project}
            ''
          ))));
in
stdenv.mkDerivation {
  pname = "l4t-devicetree";
  version = "${l4tVersion}";
  src = l4t-devicetree-sources;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # See bspSrc/source/Makefile
  makeFlags = [
    "KERNEL_HEADERS=${kernel.src}"
    "KERNEL_OUTPUT=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  buildFlags = "dtbs";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/
    # See kernel-devicetree/generic-dts/Makefile
    # The dtbs are installed to kernel-devicetree/generic-dts/dtbs
    install -Dm644 kernel-devicetree/generic-dts/dtbs/* "$out/"

    runHook postInstall
  '';
}
