# NOTE: All fixups must be at least binary functions to avoid callPackage adding override attributes.
{ lib, libnvjitlink }:
prevAttrs: { buildInputs = prevAttrs.buildInputs or [ ] ++ [ (lib.getLib libnvjitlink) ]; }
