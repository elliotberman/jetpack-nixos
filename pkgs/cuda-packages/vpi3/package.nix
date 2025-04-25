{ buildFromDebs
, debs
, l4t-3d-core
, l4t-core
, l4t-cupva
, l4t-multimedia
, libcufft
, libnpp
,
}:
buildFromDebs {
  pname = "vpi3";
  version = debs.common.vpi3-dev.version;
  srcs = [
    debs.common.libnvvpi3.src
    debs.common.vpi3-dev.src
  ];
  sourceRoot = "source/opt/nvidia/vpi3";
  buildInputs = [
    l4t-core
    l4t-3d-core
    l4t-multimedia
    l4t-cupva
    libcufft
    libnpp
  ];
  patches = [ ./vpi3.patch ];
  postPatch = ''
    rm -rf etc
    substituteInPlace lib/cmake/vpi/vpi-config.cmake --subst-var out
    substituteInPlace lib/cmake/vpi/vpi-config-release.cmake \
      --replace "lib/aarch64-linux-gnu" "lib/"
  '';
}
