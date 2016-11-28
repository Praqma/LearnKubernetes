#version=DEVEL
# System authorization information
auth --enableshadow --passalgo=sha512
# Use CDROM installation media
cdrom
# Use graphical install
graphical
# Run the Setup Agent on first boot
firstboot --enable
ignoredisk --only-use=vda
# Keyboard layouts
keyboard --vckeymap=no --xlayouts='no'
# System language
lang en_US.UTF-8

# Network information
network  --bootproto=static --device=ens3 --gateway=10.240.0.1 --ip=10.240.0.42 --nameserver=10.240.0.1 --netmask=255.255.255.0 --noipv6 --activate
network  --hostname=lb2.example.com
# Root password (redhat)
rootpw --iscrypted $6$a.26ywQsgJJ.ben6$NhB.p.q3wN6e2YzixvmnzFUa6hbPllMkQeH64QopC4uvJ/1QVgUp0kEUQCmG4vHCQsutj5b7iZ.dhMcH9WtId/
# System services
services --enabled="chronyd"
# System timezone
timezone Europe/Oslo --isUtc
# System bootloader configuration
bootloader --location=mbr --boot-drive=vda
# Partition clearing information
clearpart --none --initlabel
# Disk partitioning information
part / --fstype="xfs" --ondisk=vda --size=3583
part swap --fstype="swap" --ondisk=vda --size=512

%packages
@^server-product-environment
chrony

%end

%addon com_redhat_kdump --disable --reserve-mb='128'

%end

%anaconda
pwpolicy root --minlen=0 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy user --minlen=0 --minquality=1 --notstrict --nochanges --emptyok
pwpolicy luks --minlen=0 --minquality=1 --notstrict --nochanges --emptyok
%end
