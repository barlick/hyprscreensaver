Welcome to the hyprscreensaver terminal application.
This is for use with the linux hyprland display manager and implements a simple screensaver capability that uses "ffplay" to play a chosen screensaver video file.

Required packages:

swayidle

The hyprscreensaver app uses swayidle to monitor keyboard and mouse input and if no activity is detected then it will launch the screensaver video player via ffplay.
To install swayidle on Arch: sudo pacman -S swayidle
To install swayidle on Debian/Ubuntu distro: sudo apt install swayidle

hyprctl

The hyprscreensaver app uses the hyprland "hyprctl" module to detect monitor and workspace configuration, switch monitor focus and active workspace, lauch "ffplay" to play a selected screensaver video file and to enable/disable "swayidle" as necessary.


ffplay



Usage: -h = Display help information.
Usage: -c <folder and filename for custom hyprscreensaver.conf override file>
Usage: -d = Display additional diagnostic information.

Parameters used within the hyprscreensaver.cof file:

The "delay = <seconds>" parameter e.g. "delay = 900" is the number of seconds to wait before "swayidle" runs hyprscreensaver.
The default is 60 seconds which is 1 minute and the minimun allowed value is 30 seconds.
Example delay seconds values: 60 = 1 minute, 600 = 10 minutes, 900 = 15 minutes, 1800 = 30 minutes, 3600 = 1 hour.

The "screensaver_folder = <folder containing your screensaver video files>" parameter indicates the folder containing your screenshot video files.'
The default is "~/.config/hypr/" which should be OK to use in most cases.

The "screensaver_filename = <screensaver video filename>" parameter indicates the screenshot video file in the screensaver folder that you want to play via "ffplay" on each monitor when hyprscreensaver runs.
NOTE: If you set screensaver_filename to blank (screensaver_filename =) or "screensaver_filename = random" then hyprscreensaver will select a random screensaver video file
present in the screensaver folder. Valid video file extensions for "random" mode video file selection are .mkv, .mp4, .avi, .mov, .wmv and .webm.

The "monitorswitchdelaybefore" parameter indicates the number of milliseconds to wait before switching between monitors and workspaces. Increase this if your computer is having trouble launching the screensaver video players.
The "monitorswitchdelayafter" parameter indicates the number of milliseconds to wait after switching between monitors and workspaces. Increase this if your computer is having trouble launching the screensaver video players.');
The "launchscreensaverdelaybefore" parameter indicates the number of milliseconds to wait before launching ffplay to run a screensaver video file. Increase this if your computer is having trouble launching the screensaver video players.');
The "launchscreensaverdelayafter" parameter indicates the number of milliseconds to wait after launching ffplay to run a screensaver video file. Increase this if your computer is having trouble launching the screensaver video players.');

The "add_monitor_name = <monitor name found using hyprctl monitors> run_screensaver_on_workspace = <prefered screensaver workspace number>" is used to manually define a monitor to run a screensaver on.
You need an "add_monitor_name" line for each of your connected monitors.
So if you have two monitors then you would run the command "hyprctl monitors" in a terminal which would give you the names of both of your monitors.
In my case I do have two monitors and "hyprctl monitors" told me that they were called "HDMI-A-1" and "HDMI-A-2".
So I would add the following two "add_monitor_name" lines:

add_monitor_name = HDMI-A-1 run_screensaver_on_workspace = 8
add_monitor_name = HDMI-A-2 run_screensaver_on_workspace = 9

You can also simply add a single "add_monitor_name" line "add_monitor_name = auto run_screensaver_on_workspace = auto". That will force hyprscreensaver to query hyprctl to automatically work out your connected monitor names and calculate suitable default workspaces to run screensavers on for those monitors.
This *should* work in most cases so hence it''s used by default but it it doesn't then you will have to add "add_monitor_name" lines manually as described above.
