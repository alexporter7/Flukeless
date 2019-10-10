# Flukeless

Authors: 

Alex Porter

Canyon Shapiro

Dan Parr

Description: Port Scanner that allows you to find your IP address, Switch Name, Switch IP address, and VLAN

# Usage

The application is a WPF form with a PowerShell back end, click the start button and the application will start. It will check for Wireshark and Npcap as these are dependencies. If not installed it will install Wireshark silently and have you run thorugh the Npcap installer. It will automatically select an ethernet adapter if there is only one, however if there are multiple you can select the proper adapter.

# Changelog

=== Version 2.4 ===
- Added an auto select for adapter


=== Version 2.0 ===
- Added full GUI for operation
- Updated and added code to increase clarity
- Added dependancy check and npcap custom installation
- Added the ability to change the default TShark directory
- The program will now create it's own log directory and timestamp raw packet output per scan
- Small bug fix in which the script would still attempt to output even if there was no information found
- Reformatted and cleaned up code styling and convention
- Added safe guard to allow Npcap to only be used by administrator
- Force script to prompt to run as admin
- Added cleanup function to remove npcap + Wireshark afterwards, silently
