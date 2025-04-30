{ deb-builder }:
deb-builder {
  sourceName = "nvidia-l4t-dla-compiler";
  packageName = "libnvdla_compiler";
  outputs = [
    "out"
    "dev"
    "include"
    "lib"
    "static"
    "stubs"
  ];
  releaseInfo = {
    license = "CUDA Toolkit";
    name = "libnvdla_compiler";
  };
}
