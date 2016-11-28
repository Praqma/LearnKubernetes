#version=DEVEL
# System authorization information
auth --enableshadow --passalgo=sha512
# Use CDROM installation media
# cdrom
# Use graphical install
# graphical or text
text
skipx
# Run the Setup Agent on first boot
firstboot --disable
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=no --xlayouts='no'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=ens3 --gateway=10.240.0.1 --ip=10.240.0.41 --nameserver=10.240.0.1 --netmask=255.255.255.0 --noipv6 --activate
network  --hostname=lb1.example.com
firewall --disabled
selinux  --disabled
# Root password
rootpw --iscrypted $6$a.26ywQsgJJ.ben6$NhB.p.q3wN6e2YzixvmnzFUa6hbPllMkQeH64QopC4uvJ/1QVgUp0kEUQCmG4vHCQsutj5b7iZ.dhMcH9WtId/
sshkey --username root ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAx+5TIvYxBryI9d3DjvAeDv4q8xycNbXAAmfOIwhXL0D7So67MpmnQavwHaE/dVsGzP/9XMcidOYl7xBK0aN0fozApThWHaeKpWuJC2w4qE0ijD6tCAbnA7/Wach1rEmGVtRKo5B5lpPXuTedoixM/St/T46wnLFIwsDdFOTMyk9QHRtQ+uJAKv/lkuimMZjDRWeJE5ggwR4SNsc306R9ArnDBdj9HJ3xeUb5rqiBCe1qV3a5k8MpjsaIgG8KPx5dvXRhOTFE4ueh+2wLMy6ydy68NU5kltBtxqBA8CYbEyYmUL/cqRdx6ZVkL8AT5Pv44e2JRnN3kE70HJADfoDX5w== kaz@parqma.net
# System services
services --enabled="chronyd"
# System timezone
timezone Europe/Oslo --isUtc
# System bootloader configuration
bootloader --location=mbr --boot-drive=vda
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --fstype="xfs" --ondisk=vda --size=3500 --grow
part swap --fstype="swap" --ondisk=vda --size=512

reboot

%packages
@^server-product-environment
chrony

%end


