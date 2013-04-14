OpenEmu to Archive.vg Matcher
=============================
OpenEmu gives you a nice looking game library by matching your ROMs to archive.vg, giving you automatically the correct titles and nice cover art.
However, at the moment it relies on some sort of ROM checksum (I guess?) and most of my ROMs are not recognized.
For that reason, I wrote a script which does a fuzzy search on the ROM titles and helps you to match your ROMs to the corresponding ID in archive.vg.
If there is no unique match on the title, an interactive selection menu opens.
When finished, you can apply the correct title / coverart with two clicks in OpenEmu. 

Tested with Ruby 1.9.3. 
Have fun! No warranties if you mess up your library - make a backup first!

![ScreenShot](https://raw.github.com/yesnocancel/openemu-archivevg-matcher/master/screenshot.png)

Usage
-----
* Quit OpenEmu!
* Insert your archive.vg API key
```
./ruby  
```
* Restart OpenEmu
* Mark and select the corresponding ROMs
* Right-click and select "Get Cover Art from archive.vg".
