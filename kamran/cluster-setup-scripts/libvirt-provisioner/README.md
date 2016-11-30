# The libvirt machine provisioner
Designed to provision virtual machines using kvm/libvirt. Instead of provisioning each node painstakingly, or provisioning one and the ngoing through cloning and manually changing various OS configurations, here is a solution which uses tools provided by libvirt in concert with standard linux provisioning tools, such as kickstart.

# Pre-requisits / setup:
* You need to have the Server DVD ISO for Fedora 24 or higher - extracted (or loop mounted) in a directory on file system. If you don't have it already, download it from Fedora download URL, [here](https://getfedora.org/en/server/)
* The directory containing the fedora content should be inside the document root of the web server you will be running. See next point.
* You need to be able to run a web server (port 80), so we can use it to publish the Fedora DVD contents, and also the kickstart files.
* The document root directory of the web server (e.g. apache) (/var/www/html) will have two subdirectories inside it. 
** `cdrom` and `kickstart` . 
* If the Fedora DVD is extracted it needs to be in this `/var/www/html/cdrom` directory. 
* If the Fedora DVD ISO is to be loop mounted, it needs to be loop mounted on `/var/www/html/cdrom`.
* If you use nginx, adjust the paths accordingly.
* The kickstarts need to be copied into `/var/www/html/kickstart` 
* You can also use an apache (httpd) or nginx docker container to serve the content. (You get more geek points!)

## Libvirt setup adjustment:
Since I will be running all the project commands as normal user, I would very much like to use my regular user `kamran` to be able to execute all libvirt provided tools , or, manage vms. (By default, only root is able to do that). So, to be able to do that, I need to do few small adjustments to libvirt setup.

Add my user `kamran` to the group named `libvirt` . Then, save the following code as a PolKit file:

```
cat > /etc/polkit-1/rules.d/49-org.libvirt.unix.manager.rules << POLKITEOF
/* Allow users in kvm/libvirt group to manage the libvirt
daemon without authentication */
polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" &&
        subject.isInGroup("libvirt")) {
            return polkit.Result.YES;
    }
});
POLKITEOF
```

Then, execute the following on your current bash shell - as user `kamran`. 
```
export LIBVIRT_DEFAULT_URI=qemu:///system
```

Make sure that you also add the same to your ~/.bash_profile
```
echo "export LIBVIRT_DEFAULT_URI=qemu:///system" >> ~/.bash_profile 
```


Ideally, you will not need to restart libvirtd service. You can do that if you want to!

At this point, you should be able to list machines, or do any other thing with libvirt daemon, as a regular user.

```
[kamran@kworkhorse ~]$ virsh list --all
 Id    Name                           State
----------------------------------------------------
 -     Alpine-3.4.5-64bit             shut off
 -     endian-firewall                shut off
 -     test                           shut off
 -     win2k12r2                      shut off

[kamran@kworkhorse ~]$ 
```


## 



