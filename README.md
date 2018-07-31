# Mounting Yard

A simple Mac application that allows you to see and connect to your favourite mount points in the menu bar.

The functionality provided by the finder (using the 'Connect to Server…' menu) is great, however means that you have to have the finder active in order to quickly connect.  Additionally the finder UI does not support friendly naming, thus you have to understand the difference between (eg) `smb://144.33.1.1` and `smb://144.33.1.2` in your brainz if your connection points are not mapped within a DNS

Supported mount point types :-

* `afp://`
* `smb://`
* `cifs://`
* `ftp://`

If a scheme is provided that the application doesn't support, it passes it on to the Finder to attempt to locate a program to support the URL.

For example :-

* `vnc://`  (opens Screen Sharing)
* `rdp://`  (if you have Microsoft Remote Desktop installed, it will attempt to open it)


## Interface
The main interface lives in the menu bar, with a menu to allow your mounting points to be quickly accessed.

![./Mounting%20Yard/Art/menu.png](./Mounting%20Yard/Art/menu.png)

## Settings

The stored mounting points are accessed via the `Settings…` menu from the main Mounting Point menu.

![./Mounting%20Yard/Art/settings.png](./Mounting%20Yard/Art/settings.png)

Note that this version doesn't support storing passwords.  If you want automatic connection to a mount point use the standard server connection dialog that appears when you connect to a server to remember the password in the keychain.

![./Mounting%20Yard/Art/standard_conenction_dialog.png](./Mounting%20Yard/Art/standard_conenction_dialog.png)

## Spotlight

Mounting Yard stores the settings for a server as a file on your hard drive, which is indexed by Spotlight.  Thus, you can use spotlight to quickly access a mount point (even if its not currently connected) with a simple spotlight search

Due to sandbox restrictions, the files are stored in

`/Users/<user>/Library/Containers/com.darrenford.Mounting-Yard/Data/Documents/`

which allows for both spotlight indexing and time machine backups

![./Mounting%20Yard/Art/spotlight.png](./Mounting%20Yard/Art/spotlight.png)

## Thanks

Application icon from [noto-emoji](https://github.com/googlei18n/noto-emoji), provided under the [Apache license, version 2.0](https://github.com/googlei18n/noto-emoji/blob/master/LICENSE)