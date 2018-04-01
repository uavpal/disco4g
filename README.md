# About disco4g

Disco4g is a LTE/4G software mod for Parrot Disco drone. It adds capability to connect Disco with SkyController 2 (SC2) and Free Flight Pro app (FFP) over 4G datalink - and possibly operate drone beyond its wifi coverage limits. Both control/telemetry and live video should be working - given that enough 4G data bandwidth is available in flying area.

What needs to be modded:
* Disco firmware
* SkyController 2 firmware (optional)

## Parrot Disco over LTE/4G Demo (Youtube)

[![Parrot Disco over LTE/4G Demo](https://img.youtube.com/vi/1Txyy7Xstms/0.jpg)](https://www.youtube.com/watch?v=1Txyy7Xstms)

## Status

NB! This is still an EXPERIMENTAL hack, no thorough testing has been conducted! Mod and fly your Disco entirely at YOUR OWN RISK!!!

What seems to be working so far:
* Drone discovery and connection initialization - which for some reason takes about 3x longer than normally (10s vs 30s)
* Receiving video stream in FFP app (expect higher latency due 4G nature)
* Recovering datalink when 4G disconnects/reconnects happen
* Switching from Wifi to 4G profile and vice versa (manually from FFP app)

TODOs:
* Clean up scripts and add comments
* Introduce main config files and reconfiguration at boot
* Write installers
* Improve documentation
* Test and optimize

## Requirements

* Parrot Disco drone (firmware v1.4.1)
* Parrot SkyController 2 (firmware v1.0.7)
* Raspberry Pi 2/3 (OS Rasbian Stretch Lite)
* USB Wifi dongle for Raspberry Pi with AP and IE (Information Elements) capabilities
* 2x Huawei E3372h LTE/4G USB dongles
* 2x 4G SIMs with data plans capable of video streaming
* Cloud VM with public IP for VPN server - or attach public IP to one of the 4G SIMs (depends also on your mobile operator)

## Theory of Operation

![lte mod diagram](images/lte-mod-diagram.png)

TODO

## Installation instructions

* [Disco/CHUCK](Disco/README.md)
* [SkyController 2](SC2/README.md)
* [Raspberry Pi](RPi/README.md)
* [VPN Server](VPN/README.md)

## Usage instructions

TODO
