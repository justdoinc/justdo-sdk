# <a href='https://www.justdo.com'><img src='https://app.justdo.com/layout/logos-ext/justdo_logo_with_text_webapp_navbar.png' height='30' alt='JustDo SDK'></a>

JustDo is a Business Operating System.

With the JustDo SDK you can:

* Run JustDo on your own premise/cloud
* Extend JustDo for your business needs by writing plugins
* Modify the way any aspect of JustDo operates - both Server Side and Client Side

## Quick Start

```bash
bash <(curl https://justdo.com/sdk.bash)
```

The install script will create in the folder in which you called the command a folder named justdo
that contains all the components of the JustDo SDK.

Call the `$ justdo` command to control and perform operations on the newly installed JustDo SDK.

## Installation environmnet pre requirements

### Linux

* Bash >= v4.3
* Recent Docker installation

### macOS

* <a href="https://docs.docker.com/docker-for-mac/">Recent Docker installation</a>
* <a href="http://brew.sh/">Homebrew</a>

### Windows

Windows isn't supported at the moment.

## Uninstalling JustDo

To uninstall JustDo call the following command:

```bash
justdo uninstall
```

It will:

* Remove the `$ justdo` command
* Remove the `~/.justdo` file from your home folder
* Will stop and remove all the JustDo SDK's Docker containers installed by the JustDo SDK
* To avoid accidental data loss, it won't remove your global data folder from /var/justdo
(or /private/var/justdo/) .
