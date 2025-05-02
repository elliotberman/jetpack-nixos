{ l4tVersion
, dockerTools
, writeShellScriptBin
, pkgs
}:
let
  l4tImage = dockerTools.pullImage {
    imageName = "nvcr.io/nvidia/l4t-jetpack";
    imageDigest = "sha256:34ccf0f3b63c6da9eee45f2e79de9bf7fdf3beda9abfd72bbf285ae9d40bb673";
    finalImageTag = "r36.4.0";
    sha256 = "sha256-+5+GRmyCl2ZcdYIJHU5snuFzEx1QkZic9bhtx9ZjXeo=";
    os = "linux";
    arch = "arm64";
  };
in
{
  oci = writeShellScriptBin "oci-test" ''
    image=${l4tImage.imageName}:${l4tImage.imageTag}
    container_commands="apt-get update && apt-get install --yes cmake build-essential && wget https://github.com/NVIDIA/cuda-samples/archive/refs/tags/v12.9.tar.gz && tar xf v12.9.tar.gz && mkdir cuda-samples-12.9/build && cd cuda-samples-12.9/build && cmake -DBUILD_TEGRA=True .. ; make -C Samples/1_Utilities/deviceQuery && Samples/1_Utilities/deviceQuery/deviceQuery"

    for runtime in docker podman; do
      if command -v $runtime 2>&1 >/dev/null; then
        echo "testing $runtime runtime"
      else
        echo "$runtime runtime not found, skipping"
        continue
      fi

      "$runtime" load --input=${l4tImage}

      if "$runtime" run --rm "$image" bash -c "$container_commands"; then
        echo "container run w/o nvidia passthru unexpectedly succeeded"
        exit 1
      fi

      if ! "$runtime" run --rm --device=nvidia.com/gpu=all "$image" bash -c "$container_commands"; then
        echo "container run w/nvidia passthru unexpectedly failed"
        exit 1
      fi

      "$runtime" image rm "$image"
    done
  '';
}
