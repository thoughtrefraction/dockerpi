#!/bin/sh

target="${1:-pi1}"
image_path="/sdcard/filesystem.img"
zip_path="/filesystem.zip"
cpu="--cpu arm1176"
if [ ! -e $image_path ]; then
  echo "No filesystem detected at ${image_path}!"
  if [ -e $zip_path ]; then
      echo "Extracting fresh filesystem..."
      unzip $zip_path
      mv *.img $image_path
  else
    exit 1
  fi
fi

if [ "${target}" = "pi0" ]; then
  emulator=qemu-system-arm
  kernel="/root/qemu-rpi-kernel/kernel-qemu-5.4.51-buster"
  dtb="/root/qemu-rpi-kernel/versatile-pb-buster-5.4.51.dtb"
  machine=virt
  cpu=""
  memory=512m
  root=/dev/sda2
  nic='--net nic --net user,hostfwd=tcp::5022-:22'
elif [ "${target}" = "pi1" ]; then
  emulator=qemu-system-arm
  kernel="/root/qemu-rpi-kernel/kernel-qemu-5.4.51-buster"
  dtb="/root/qemu-rpi-kernel/versatile-pb-buster-5.4.51.dtb"
  machine=versatilepb
  memory=256m
  root=/dev/sda2
  nic='--net nic --net user,hostfwd=tcp::5022-:22'
elif [ "${target}" = "pi2" ]; then
  emulator=qemu-system-arm
  machine=raspi2
  memory=1024m
  kernel_pattern=kernel7.img
  dtb_pattern=bcm2709-rpi-2-b.dtb
  nic=''
elif [ "${target}" = "pi3" ]; then
  emulator=qemu-system-aarch64
  machine=raspi3
  memory=1024m
  kernel_pattern=kernel8.img
  dtb_pattern=bcm2710-rpi-3-b-plus.dtb
  nic=''
else
  echo "Target ${target} not supported"
  echo "Supported targets: pi0 pi1 pi2 pi3"
  exit 2
fi

if [ "${kernel_pattern}" ] && [ "${dtb_pattern}" ]; then
  fat_path="/fat.img"
  echo "Extracting partitions"
  fdisk -l ${image_path} \
    | awk "/^[^ ]*1/{print \"dd if=${image_path} of=${fat_path} bs=512 skip=\"\$4\" count=\"\$6}" \
    | tail -n 1 | sh

  echo "Extracting boot filesystem"
  fat_folder="/fat"
  mkdir -p "${fat_folder}"
  fatcat -x "${fat_folder}" "${fat_path}"

  root=/dev/mmcblk0p2

  echo "Searching for kernel='${kernel_pattern}'"
  kernel=$(find "${fat_folder}" -name "${kernel_pattern}")

  echo "Searching for dtb='${dtb_pattern}'"
  dtb=$(find "${fat_folder}" -name "${dtb_pattern}")
fi

if [ "${kernel}" = "" ] || [ "${dtb}" = "" ]; then
  echo "Missing kernel='${kernel}' or dtb='${dtb}'"
  exit 2
fi

echo "Booting QEMU machine \"${machine}\" with kernel=${kernel} dtb=${dtb}"
exec ${emulator} \
  --machine "${machine}" \
  #--cpu arm1176 \
  ${cpu} \
  --m "${memory}" \
  --drive "format=raw,file=${image_path}" \
  ${nic} \
  --dtb "${dtb}" \
  --kernel "${kernel}" \
  --append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=${root} rootwait panic=1" \
  --no-reboot \
  --display none \
  --serial mon:stdio
