# NOTE: All fixups must be at least binary functions to avoid callPackage adding override attributes.
{ lib
, libcublas
, libcusparse
, libnvjitlink
}:
prevAttrs: {
  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    (lib.getLib libcublas)
    (lib.getLib libcusparse)
    (lib.getLib libnvjitlink)
  ];
}
