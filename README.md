# Ruby iTunes/Apple Music to Android FTP

This is a ruby application for copying your iTunes/Apple Music tracks and playlists to android devices.

The user selects which playlists to copy, and there's a copy progress bar and status so you know exactly how far along the copy is.

It will try to use iSyncr tracks already copied to the device if possible.

It uses FTP for the file transfer, so technically any device or machine that can run FTP can work.
There's a free android file browser called [File Manager Plus](https://play.google.com/store/apps/details?id=com.alphainventor.filemanager) that has an FTP option built-in that works well.

I've tested it on Mac and PC, but it should run in linux as well.

This is alpha software; I haven't tested it on a very large iTunes library with thousands of songs yet. Still, I think it may already work well enough to be useful.

![image](https://github.com/andrewroth/ruby_itunes_apple_music_to_android/assets/13490/cb9522c8-b998-417e-82fa-0622191300fd)

## Exporting from iTunes/Apple Music

Unfortunately, I couldn't find a way to extract the iTunes/Apple Music library, so you'll have to go
File -> Library -> Export Library... and save Library.xml to the app folder. This has to be done every
time. It could perhaps be automated with AppleScript on macs. 

## iSyncr

There's a program and companion app called iSyncr that used to work well, but in my experience, since
the company was sold, has not worked well. It became extremely slow. I thought, "I can do better",
and this program is the result. I made sure to add lots of progress bars and status labels to indicate
what the program is doing. Copying that much data can be slow, but at least the user will know how far
along things are.

This program is compatible with iSyncr folders. After telling it what path to the iSyncr music folder
on your device, it will scan the folder and determine matches to your iTunes/Apple Music library tracks.
It uses file size as the main metric, and file name as a secondary one. Generally, this has worked well,
but if you come across an instance where it doesn't, please leave an issue report.

## Installation

Unfortunately, I haven't had time to try to package this nicely, so you'll have to do some command line
work to get it installed, but it's fairly standard stuff.

1. Install ruby. For compatibility I recommend ruby 2.7 but more recent versions should work as well. For
  mac and linux, try rbenv or rvm and look at their docs for how to install it, then install ruby from that.

2. Install "TK". Google your operating system + "tk install guide" for instructions as people have written
   guides. In my experience, it's not too hard; there's prepackaged TK installs available.

3. Clone this repo and run `bundle install` to get the required gems installed.

4. run `ruby run.rb` to run the app, or run "run.mac" which is a simple applescript file I made to run the
   app in a terminal window.

If you need help, let me know and I'll try to help and make a wiki entry or something.

Helpful links:

 - This has worked for me on PC: https://sourceforge.net/projects/magicsplat/files/magicsplat-tcl/
 - This has worked for me on mac: https://platform.activestate.com/danac/ActiveTcl-8.6/distributions?platformID=aa7c0abf-d4a2-5896-8220-41c88b42c6c4
 - https://tkdocs.com/tutorial/install.html

## Process

1. On the first run, enter the config options. They will be saved to disk.

2. Export the playlist from iTunes/Apple Music manually and save Library.xml to the folder root.

3. Run the FTP server on your device. (In File Manager Plus, it's "Access from network"; turn off random
   password to avoid having to enter it every time)

6. Click "Scan Device".

7. Click on the playlist rows in the table to select the ones to copy.

8. When that completes, click "Copy To Device"

## Approach/Code/Improvements

I'm a rails developer and not an application developer so I did my best to categorize the code into logical
models, views and lib.

Some ideas I have for future work:

- deletion of files or playlists from device
- tabs to make the UI cleaner. Ex. "Config", "About", "Copy", "Log", etc.
- indication of device space used/free
- refactor track and playlist into their own model (and numerous other code cleanups)
- add standardrb to keep ruby style consistent

By all means, let me know of any feature requests and bugs. I'm glad to look at pull requests and add other
developers if there's interest.

## License

I made this GPL because I would like to keep it a free and open and not go like iSyncr did, and have it always
open, free and accessible.
