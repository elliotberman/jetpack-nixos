# NOTE: All fixups must be at least binary functions to avoid callPackage adding override attributes.
{ lib
, libcublas
, zlib
,
}:
let
  inherit (lib.attrsets) getLib;
in
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    (getLib libcublas)
    zlib
  ];

  postFixup =
    prevAttrs.postFixup or ""
    + ''
      pushd "''${!outputLib:?}/lib" >/dev/null
      ln -s libcudnn.so.9 libcudnn.so
      popd >/dev/null

      echo "creating symlinks for header files in include without the _v9 suffix before the file extension"
      pushd "''${!outputInclude:?}/include" >/dev/null
      for file in *.h; do
        echo "symlinking $file to $(basename "$file" "_v9.h").h"
        ln -s "$file" "$(basename "$file" "_v9.h").h"
      done
      unset -v file
      popd >/dev/null
    '';

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
