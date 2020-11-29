# Automated Nativefier

Nativefier does not take care of actually installing the resulting electron app in your Linux system. The purpose of this program is to do that.

What it does:

- create an executable that let you run the electron app from the terminal,
- generates a `.desktop`  entry so that you can launch the electron app from an application launcher,
- places the Nativefier generated icon in the appropriate directory.

### Usage

Run `nativefier.sh` for an interactive session. If you want to automate the process, use command-line arguments and the `-y` options to automatically confirm. 

```bash
nativefier.sh --pkgname 'Messages' --name 'Google Messages' --desc 'Google Messages for Web' --url 'messages.google.com/web/conversations' -y
```

* `--pkgname` is the name of the executable.
* `--name` will be name of the app in the application launcher.
* `--desc` usually appears as a tooltip or descriptive comment next to the app name in the application launcher. 
* `--url` is the address of the web page you want to convert.
* `-y` tells the program to automatically confirm. Usually you will be prompted for confirmation and given a chance to change all values.

You can also use automate part of the interactive session by setting the question values in the command-line. For example, the  `--nativefier` (or shorthand `-N`) option let you pass arguments directly to the Nativefier process,  you can automate this part accordingly:

```bash
nativefier.sh -N 'maximize,tray start-in-tray,single-instance'
```

You’ll still be prompted for the usual questions in the interactive session and can still change the parameters (unless you use the `-y` option). 

### Manual

All command-line options are optional unless you use the `-y` option which will fail if the following options are missing:

- `--pkgname`,
- `--name`,
- `--url`.



#### The Nativefier process

You can pass arguments to the Nativefier process directly by using the `--nativefier` or `-N` option which expects a comma-separate string of valid Nativefier arguments (see `--args`):

```bash
nativefier.sh -N 'maximize,tray start-in-tray,single-instance,icon icon.png'
```

Dashes are unnecessary, the correct option will be inferred for you. That is, you don’t have to use this format but you can if you want to:

 ```bash
nativefier.sh -N '--maximize,--tray start-in-tray,--single-instance,--icon icon.png'
 ```

Note! The program *does not* check if the arguments you pass to Nativefier are valid.