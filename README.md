# NetDistrict
NetDistrict is a Netlogo model that lets you investigate different score functions and the impact they have on districting.

Currently, it's mostly useful as a neat example generator that can help explain some concepts relevant to gerrymandering. It's not a tool for especially deep analysis; however, a lot of the grunt work is out of the way to expand it in the future.

For more information, consult the Info tab of the model itself. That is the documentation source of truth; this is just enough to let you know whether it's worth your time to check it out.

## Setup

Download the newest version of Netlogo from here: https://ccl.northwestern.edu/netlogo/download.shtml

Currently, the only extension Netdistrict uses is the "nw" extension, which comes bundled in with Netlogo. However, I have noticed a problem with Netlogo 6.x where the bundled nw extension is actually the Netlogo 5 one. If that happens to you, go download the most recent version of nw here: https://github.com/NetLogo/NW-Extension

Extract that folder, and rename the folder to "nw" if it's not called that already. Then go to Netlogo -> app -> extensions and replace the "nw" folder there with the new one.

From there, you should just be able to open the model and have it work. 

## Tips for Netlogo Neophytes

Hit the "Setup" button when you first launch the model, whenever you want to restart the model, and whenever you change a parameter via a slider or chooser. Changing a parameter mid-way and trying to re-run the same model may result in errors or crashes.

If you don't like the range of values for a given slider, you can right click and edit it to your hearts content.

You can right-click on a block or patch to get more information. I also store some district-level information in each patch that compromises a district. Note that while you technically can change values from this screen, it won't actually work the way you expect and can potentially cause errors or crashes. If you have a use case for modifying blocks directly, give me more details - I might be able to code a helper function to make it possible..
