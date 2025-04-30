# NOTE: All fixups must be at least binary functions to avoid callPackage adding override attributes.
{ lib
, libcublas
, patchelf
, zlib
,
}:
let
  inherit (lib.attrsets) getLib;
  inherit (lib.meta) getExe;
in
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    (getLib libcublas)
    zlib
  ];

  meta = prevAttrs.meta or { } // {
    homepage = "https://developer.nvidia.com/cudnn";
    license = {
      shortName = "cuDNN EULA";
      fullName = "NVIDIA cuDNN Software License Agreement (EULA)";
      url = "https://docs.nvidia.com/deeplearning/sdk/cudnn-sla/index.html#supplement";
      free = false;
      redistributable = true;
    };
  };
}
