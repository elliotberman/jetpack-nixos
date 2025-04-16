{ lib
, preFlashCommands ? ""
, flashCommands ? ""
, postFlashCommands ? ""
, flashArgs ? [ ]
, partitionTemplate ? null
, socType ? null
, # Optional directory containing DTBs to be used by flashing script, which can
  # be used by the bootloader(s) and passed to the kernel.
  dtbsDir ? null
, # Optional package containing uefi_jetson.efi to replace prebuilt version
  uefi-firmware ? null
, # Optional package containing tos.img to replace prebuilt version
  tosImage ? null
, # Optional EKS file containing encrypted keyblob
  eksFile ? null
, # Additional DTB overlays to use during device flashing
  additionalDtbOverlays ? [ ]
, flash-tools
}:
(''
  set -euo pipefail

  if [[ -z ''${WORKDIR-} ]]; then
    WORKDIR=$(mktemp -d)
    function on_exit() {
      rm -rf "$WORKDIR"
    }
    trap on_exit EXIT
  fi

  cp -r ${flash-tools}/. "$WORKDIR"
  chmod -R u+w "$WORKDIR"
  cd "$WORKDIR"

  # Make nvidia's flash script happy by adding all this stuff to our PATH
  export PATH=${lib.makeBinPath flash-tools.flashDeps}:$PATH

  export NO_ROOTFS=1
  export NO_RECOVERY_IMG=1
  export NO_ESP_IMG=1

  export ADDITIONAL_DTB_OVERLAY=''${ADDITIONAL_DTB_OVERLAY:+$ADDITIONAL_DTB_OVERLAY,}${lib.concatStringsSep "," additionalDtbOverlays}

  ${lib.optionalString (partitionTemplate != null) "cp ${partitionTemplate} flash.xml"}

  ${preFlashCommands}

  chmod -R u+w .

'' + (if (flashCommands != "") then ''
  ${flashCommands}
'' else ''
  ./flash.sh ${lib.optionalString (partitionTemplate != null) "-c flash.xml"} "$@" ${builtins.toString flashArgs}
'') + ''
  ${postFlashCommands}
'')
