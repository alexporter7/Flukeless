# Flukeless

Authors: 
Alex Porter
Canyon Shapiro
Dan Parr

Description: Port Scanner that allows you to find your IP address, Switch Name, Switch IP address, and VLAN

# Usage

The application is a WPF form with a PowerShell back end, click the start button and the application will start. It will check for Wireshark and Npcap as these are dependencies. If not installed it will install Wireshark silently and have you run thorugh the Npcap installer. It will automatically select an ethernet adapter if there is only one, however if there are multiple you can select the proper adapter.

# Change Log

=== Version 2.4 ===

Added an auto select for adapter
