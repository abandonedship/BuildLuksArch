#!/bin/bash

#####################################
# NAME         TYPE     MOUNTPOINTS #
# sda          disk                 #
#  |-sda1      part     /boot       #
#  |-sda2      part                 #
#  |  └─root   crypt    /           #
#  |-sda3      part                 #
#  |  └─home   crypt    /home       #
#  |-sda4      part                 #
# sr0          rom                  #
#####################################

printf "%s\n" "THIS SCRIPT IS FOR A CLEAN INSTALLATION IN YOUR /dev/sdX"
read -p "YOUR DISK WILL BE ERASED AND RE-PARTITIONED USE IT AT YOUR OWN RISK [yes/no]: " cont

if [[ "$cont" != "yes" ]]
then
	exit
fi

hostname="ghost"
username="ghost"

fdisk -l
read -p $'\n\n\e[1mEnter disk (example: /dev/sda):\e[0m ' disk_to_part
fdisk -l | grep $disk_to_part
disk_to_part_SIZE=$(fdisk -l | grep $disk_to_part | awk '{print $3}')
size_type=$(fdisk -l | grep $disk_to_part | awk '{print $4}')

## this works for GB format
if [[ $size_type == "GiB," ]]
then
	mode="G"
fi

if [[ $size_type == "MiB," ]]
then
	echo "M not available by the moment"
	exit
fi

# Calculating size
partitions_size=$(awk "BEGIN {print ($disk_to_part_SIZE-0.6)/3}")

### tricky fdisk way overriding non-interactive #
(
echo o;
echo n;
echo p;
echo 1;
echo ;
echo +512M;
echo a;
echo n;
echo p;
echo 2;
echo ;
echo +$partitions_size$mode;
echo n;
echo p;
echo 3;
echo ;
echo +$partitions_size$mode;
echo n;
echo p;
echo ;
echo ;
echo w;
echo p;
) | fdisk "$disk_to_part"
#################################################
sleep 2
printf "[\e[32m+\e[0m] \e[1mDisk was partitioned\e[0m\n"
printf "[\e[32m+\e[0m] \e[1mEncrypting\e[0m\n"

# ENCRYPT PARTITIONS
printf "[\e[32m+\e[0m] \e[1mEncrypt /dev/sda2\e[0m\n"
cryptsetup luksFormat /dev/sda2
printf "[\e[32m+\e[0m] \e[1mEncrypt /dev/sda3\e[0m\n"
cryptsetup luksFormat /dev/sda3

printf "[\e[32m+\e[0m] \e[1mUnlocking encrypted partitions\e[0m\n"
# spec
printf "[\e[32m+\e[0m] \e[1mUnlock /dev/sda2 root\e[0m\n"
cryptsetup open --type luks /dev/sda2 root
printf "[\e[32m+\e[0m] \e[1mUnlock /dev/sda3 home\e[0m\n"
cryptsetup open --type luks /dev/sda3 home

printf "[\e[32m+\e[0m] \e[1mFormating partitions\e[0m\n"
# FORMATING PARTITIONS
mkfs.ext4 /dev/mapper/root
mkfs.ext4 /dev/mapper/home
mkfs.ext4 /dev/sda1

printf "[\e[32m+\e[0m] \e[1mMounting partitions\e[0m\n"
# MOUNT PARTITIONS
mount /dev/mapper/root /mnt
sudo mkdir /mnt/home
mount /dev/mapper/home /mnt/home
sudo mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

printf "[\e[32m+\e[0m] \e[1mDownloading/Installing system and kernel\e[0m\n"
# DOWNLOAD/INSTALL SYSTEM AND KERNEL
pacstrap /mnt base base-devel linux linux-firmware nano grub networkmanager dhcpcd netctl wpa_supplicant dialog

# ADDING ENCRYPTED PARTITIONS TO CRYPTTAB
printf "[\e[32m+\e[0m] \e[1mAdding encrypted partitions to crypttab\e[0m\n"
cat << EOF >> /mnt/etc/crypttab

root /dev/sda2 none luks
home /dev/sda3 none luks
EOF

printf "[\e[32m+\e[0m] \e[1mGenerating fstab file\e[0m\n"
# GENERATING FSTAB
genfstab -U /mnt > /mnt/etc/fstab

printf "[\e[32m+\e[0m] \e[1mArch-Chrooting system\e[0m\n"
# ARCH-CHROOTING STUFF
# note: the sed -i -e 's/block/block encrypt/g' /etc/mkinitcpio.conf will overwrite itself at second try BEWARE
arch-chroot /mnt bash -c "ln -sf /usr/share/zoneinfo/Europe/Warsaw /etc/localtime && hwclock --systohc && echo LANG=en_US.UTF8 > /etc/locale.conf 66 echo KEYMAP=en > /etc/vconsole.conf && echo \"$hostname\" > /etc/hostname && echo 127.0.0.1 localhost > /etc/host && sed -i -e 's/#en_US.UTF8/en_US.UTF8/g' /etc/locale.gen && locale-gen && printf \"[\e[0;33m*\e[0m] \e[1mROOT ACCOUNT PASSWORD\e[0m\n\" && passwd && useradd -m \"$username\" && printf \"[\e[0;33m*\e[0m] \e[1m$username USER ACCOUNT PASSWORD\e[0m\n\" && passwd \"$username\" && pacman -S os-prober && sed -i -e 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"cryptdevice=\/dev\/sda2:root\"/g' /etc/default/grub && sed -i -e 's/block/block encrypt/g' /etc/mkinitcpio.conf && grub-install $disk_to_part && grub-mkconfig -o /boot/grub/grub.cfg && mkinitcpio -P"

printf "\n[\e[32m+\e[0m] \e[1mFINISHED\e[0m\n\n"
printf "%s\n" "SYSTEM NEEDS TO BE REBOOTED, DONT FORGET ENABLE NETWORK MANAGER"
printf "%s\n" "systemctl enable NetworkManager.service"
printf "%s\n" "systemctl start NetworkManager.service"
read -p "[yes/no]: " yn
if [[ "$yn" == "yes" ]]
then
	reboot
else
	printf "%s\n" "YOU WILL NEED TO RESTART SYSTEM MANUALLY"
fi


# ENABLING NETWORKMANAGER
# su
# systemctl enable NetworkManager.service
# systemctl start NetworkManager.service

# INSTALLING DESKTOP ENVIRONMENT
# pacman -S xorg-server xorg-xinit gnome xterm zsh

# ENABLING DESKTOP ENVIRONMENT
#systemctl enable gdm.service
#systemctl start gdm.service
