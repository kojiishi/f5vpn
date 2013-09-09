f5vpn
=====

This utility allows you to login to F5 VPN.

F5 VPN uses web browsers to login, and it automatically logs out when you quit the browser.
With this utility, you can keep the connection without keeping the browser open.

It also features:

* f5vpn can switch the network location on connection, and can switch back on quit,
  so that you can use different proxy server or other network settings
  only while you are connected to the VPN.

INSTALL
-------
1. Download or clone the repository and build.
2. You need to set login URL manually. See below for the details.

Login URL
---------
To set the login URL, open Terminal application and type the command below:

    defaults write ec.koji.f5vpn LoginURL https://host.name/tp

Replace _host.name_ with the host name you get from your system administrator.
