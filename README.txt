Welcome to the hyprscreensaver linux hyprland terminal screensaver application.
This is for use with the linux hyprland display manager and implements a simple screensaver capability that uses "swayidle" to detect when a specified period of inactivity has elapsed and then run "ffplay" to play a chosen screensaver video file on all of your monitors.
I coded and tested this using Arch linux but it should work OK on other distros such as Debian, Ubuntu, Linux Mint etc. as long as the hyprland display manager (dynamic tiling Wayland compositor) is in use.

Required packages:

swayidle

The hyprscreensaver app uses swayidle to monitor keyboard and mouse input and if no activity is detected then it will launch the screensaver video player via ffplay.
To install swayidle on Arch: sudo pacman -S swayidle
To install swayidle on Debian/Ubuntu type distro: sudo apt install swayidle

hyprctl

The hyprscreensaver app uses the hyprland "hyprctl" module to detect monitor and workspace configuration, switch monitor focus and active workspace, launch "ffplay" to play a selected screensaver video file and to enable/disable "swayidle" as necessary.
The hyprctl package/module is part of hyprland so should have been installed when you installed hyprland.

ffplay

The hyprscreensaver app uses the "ffplay" app to run a selected screensaver video file in full screen mode on a loop on each of your monitors.
The "ffplay" app is part of the "ffmpeg" package suite so if ffmpeg is installed on you system then ffplay should be available. Check it by running "ffplay -h" in a terminal. If ffplay isn't present then you will need to install ffmpeg.
To install ffmpeg on Arch: sudo pacman -S ffmpeg
To install ffmpeg on Debian/Ubuntu type distro: sudo apt install ffmpeg

Lazarus

The hyprscreensaver app was written using the Lazarus Free Pascal IDE.
If you want to compile hyprscreensaver yourself then you will need to install Lazarus. Please follow the documentation on their website: https://www.lazarus-ide.org/ 
Note: As at time of writing (August 2025) these terminal commands should work:
To install lazarus on Arch: 
sudo pacman -Sy lazarus
sudo pacman -Sy lazarus-qt5
To install lazarus on Debian/Ubuntu type distro: 
sudo apt install make gdb fpc fpc-source lazarus-ide-qt5 lcl-gtk2 lcl-qt5
You should then be able to run the Lazarus IDE app, load the project file "hyprscreensaver.lpr" and compile it.

If you don't want to install Lazarus and compile hyprscreensaver yourself then you can just take the x86 binary "hyprscreensaver" from the hyprscreensaver repo and use that instead.
You will need to copy the hyprscreensaver app binary file to a suitable folder e.g. "/usr/bin/" but to keep things simple, I recommend that you copy it to the default "~/.config/hypr/" folder initially.
You will also need to make it executable so run "sudo chmod +x ~/.config/hypr/hyprscreensaver" in the terminal.
You can then try running it from the terminal by typing "~/.config/hypr/hyprscreensaver -h" to show the help/usage information.
If the hyprscreensaver app won't run in the terminal then I *think* that if you install the "qt5pas" package then that should allow the hyprscreensaver binary to run:
To install qt5pas on Arch: sudo pacman -S qt5pas   
To install qt5pas on Debian/Ubuntu type distro: sudo apt install qt5pas

Once you have checked that swayidle, hyprctl and ffplay are installed and you have a working hyprscreensaver app in the "~/.config/hypr/" folder then you can proceed to test it.

From a terminal, type: ~/.config/hypr/hyprscreensaver -h
It should display the following:

Welcome to the hyprscreensaver terminal application.
This is for use with the linux hyprland display manager to facilitate a screensaver capability.
Running as: <hyprscreensaver app binary folder>/hyprscreensaver
Usage: -h = Display help information.
Usage: -c <folder and filename for custom hyprscreensaver.conf override file>
Usage: -d = Display additional diagnostic information.
NB: The default hyprscreensaver.conf file is ~/.config/hypr/hyprscreensaver.conf and is generated automatically on first run.
All further usage and configuration information is in hyprscreensaver.conf so please read that.

Next, copy the "screensaver.mp4" test screensaver video file from the hyprscreensaver repo to the default screensaver folder "~/.config/hypr/".
Next, type: "hyprscreensaver -d" in the terminal.
You should find that it gives you diagnostic information and also creates a default "hyprscreensaver.conf" file in your "~/.config/hypr/" folder.
If you then re-run "hyprscreensaver -d" then it should launch your screensaver video on each of your monitors.

If that works OK then just press a key or click on one of the video player windows and hyprscreensaver should close the screensaver video payer windows and return you to your normal hyprland desktop and selected workspace on each monitor.
It should then automatically re-run the hyprscreensaver screensaver after the default 60 seconds of inactivity (no mouse or keyboard clicks).

NB: You can stop the hyprscreensaver app from running by typing: pkill swayidle

Once hyprscreensaver is working then you can get hyprland to start up automatically when hyprland starts up.
You should just need to edit your "~/.config/hypr/hyprland.conf" file and comment out (add a "#" character to the start of a line) to any existing "exec-once = swayidle..." lines in the "Launch" section and add a new one:
exec-once = ~/.config/hypr/hyprscreensaver
If you save your modified hyprland.conf file and then re-start hyprland (or simply re-boot and log back in to hyprland) then you should find that the hyprscreensaver runs the screensaver video players after the default 60 seconds of inactivity.

Once hyprscreensaver is working correctly using the defaults, you can customise it by editing the "~/.config/hypr/hyprscreensaver.conf" file:

Parameters used within the hyprscreensaver.conf file:

The "delay = <seconds>" parameter e.g. "delay = 900" is the number of seconds to wait before "swayidle" runs hyprscreensaver.
The default is 60 seconds which is 1 minute and the minimum allowed value is 30 seconds.
Example delay seconds values: 60 = 1 minute, 600 = 10 minutes, 900 = 15 minutes, 1800 = 30 minutes, 3600 = 1 hour.

The "screensaver_folder = <folder containing your screensaver video files>" parameter indicates the folder containing your screenshot video files.'
The default is "~/.config/hypr/" which should be OK to use in most cases.

The "screensaver_filename = <screensaver video filename>" parameter indicates the screenshot video file in the screensaver folder that you want to play via "ffplay" on ALL monitors when hyprscreensaver runs.
If you set screensaver_filename to blank (screensaver_filename =) or "screensaver_filename = random" then hyprscreensaver will select a single random screensaver video file present in the screensaver folder and run that on ALL monitors.
If you set screensaver_filename to "screensaver_filename = randomforeachmonitor" then hyprscreensaver will select a random screensaver video file present in the screensaver folder for EACH monitor so that allows you to have a different random screensaver on EACH of your monitors.
Valid video file extensions for "random" and "randomforeachmonitor" modes video file selections are .mkv, .mp4, .avi, .mov, .wmv and .webm.

The "monitorswitchdelaybefore" parameter indicates the number of milliseconds to wait before switching between monitors and workspaces. Increase this if your computer is having trouble launching the screensaver video players.
The "monitorswitchdelayafter" parameter indicates the number of milliseconds to wait after switching between monitors and workspaces. Increase this if your computer is having trouble launching the screensaver video players.');
The "launchscreensaverdelaybefore" parameter indicates the number of milliseconds to wait before launching ffplay to run a screensaver video file. Increase this if your computer is having trouble launching the screensaver video players.');
The "launchscreensaverdelayafter" parameter indicates the number of milliseconds to wait after launching ffplay to run a screensaver video file. Increase this if your computer is having trouble launching the screensaver video players.');

The "add_monitor_name = <monitor name found using hyprctl monitors> run_screensaver_on_workspace = <preferred screensaver workspace number>" is used to manually define a monitor to run a screensaver on.
You need an "add_monitor_name" line for each of your connected monitors.
So if you have two monitors then you would run the command "hyprctl monitors" in a terminal which would give you the names of both of your monitors.
In my case I do have two monitors and "hyprctl monitors" told me that they were called "HDMI-A-1" and "HDMI-A-2".
So I would add the following two "add_monitor_name" lines:

add_monitor_name = HDMI-A-1 run_screensaver_on_workspace = 8
add_monitor_name = HDMI-A-2 run_screensaver_on_workspace = 9

You can also simply add a single "add_monitor_name" line "add_monitor_name = auto run_screensaver_on_workspace = auto". That will force hyprscreensaver to query hyprctl to automatically work out your connected monitor names and calculate suitable default workspaces to run screensavers on for those monitors.
This *should* work in most cases so hence it's used by default but it it doesn't then you will have to add "add_monitor_name" lines manually as described above.

So you can change the "delay" parameter from the default 60 seconds to the value (in seconds) that you prefer. 
You can set the "screensaver_folder" to a different folder.
You can change the "screensaver_filename" to either point to a different screensaver video file or set it to "random" if you have more than one screensaver video file in your "screensaver_folder" and you want hyprscreensaver to select one at random instead.
You can also change the hyprscreensaver monitor config by using "add_monitor_name" commands.
Hopefully that gives you enough control over it.

Have fun!
