{ bspSrc, runCommand }:
runCommand "l4t.csv" { } ''
  tar -xf "${bspSrc}/nv_tegra/config.tbz2"
  mkdir $out
  install etc/nvidia-container-runtime/host-files-for-container.d/*.csv $out
''
