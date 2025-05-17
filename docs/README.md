# RFID Toy Build Documentation

## Overview

The RFID toy is a simple music and audiobook player that plays audio files when specific RFID tags are detected. Place a tag on top of the device, and it plays the associated audio file through its speakers. The project uses a Raspberry Pi Zero W, an Adafruit Speaker Bonnet for audio, and an RC522 RFID reader to detect tags. A 60-LED NeoPixel ring controlled by an Arduino Nano provides visual feedback. The components are housed in a modified bluetooth speaker case.

## Hardware Components

- Raspberry Pi Zero W
- Adafruit I2S 3W Stereo Speaker Bonnet
- RC522 RFID Reader Module
- Arduino Nano
- Adafruit NeoPixel Ring (60 LEDs)

## Hardware Assembly

### Speaker Bonnet Installation

Mount the Speaker Bonnet onto the Raspberry Pi Zero W's GPIO header. Press down firmly to ensure proper connection.

### RFID Reader Connection

Connect the RC522 RFID reader to the Speaker Bonnet:

| RC522 Pin | Speaker Bonnet Label | Physical Pin (Pi) | BCM GPIO |
|-----------|---------------------|------------------|-----------|
| SDA       | CEO                 | Pin 24           | GPIO 8    |
| SCK       | CLK                 | Pin 23           | GPIO 11   |
| MOSI      | MOSI                | Pin 19           | GPIO 10   |
| MISO      | MISO                | Pin 21           | GPIO 9    |
| GND       | GND                 | Pin 6            | -         |
| RST       | Any free GPIO       | Pin 22           | GPIO 25   |
| 3.3V      | 3.3V                | Pin 1            | -         |

Note: Leave the IRQ pin unconnected.

## Software Setup

### 1. System Configuration

First, enable SPI using raspi-config:

```bash
sudo raspi-config
```

Navigate to:

* Interface Options
* SPI
* Select "Yes" to enable SPI interface
* Select "Finish" and reboot when prompted

### 2. Virtual Environment Setup

Install Python virtual environment support:

```bash
sudo apt install python3-venv
```

### 3. Speaker Bonnet Software

Install and configure the speaker bonnet:

```bash
sudo apt install -y wget
python -m venv env --system-site-packages
source env/bin/activate
pip3 install adafruit-python-shell
wget https://github.com/adafruit/Raspberry-Pi-Installer-Scripts/raw/main/i2samp.py
sudo -E env PATH=$PATH python3 i2samp.py
```

When running the installer script:

1. Decline the offer to enable background `/dev/zero` playback when prompted
2. Reboot: `sudo reboot`
3. Log back in and activate environment: `source env/bin/activate`
4. Run script again: `sudo -E env PATH=$PATH python3 i2samp.py`
5. Test the speaker when prompted
6. Reboot again: `sudo reboot` (required for volume control)

After the second reboot, set up the zero-play service to prevent audio popping:

1. Create the service file:

```bash
sudo nano /etc/systemd/system/zero-play.service
```

Add this content:

```
[Unit]
Description=Play zero device
After=sound.target

[Service]
Type=simple
ExecStart=/usr/bin/aplay -D default -t raw -r 44100 -c 2 -f S16_LE /dev/zero
Restart=always

[Install]
WantedBy=multi-user.target
```

2. Enable and start the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable zero-play
sudo systemctl start zero-play
```

### 4. Component Testing

#### RFID Reader Test

To verify the RFID reader is working, you can run this test:

```python
import RPi.GPIO as GPIO
from mfrc522 import SimpleMFRC522

GPIO.setwarnings(False)

reader = SimpleMFRC522()
try:
        id = reader.read_id()
        print(id)
finally:
        GPIO.cleanup()
```

#### Speaker Test

To verify the speaker is working correctly and test stereo channels:

```bash
wget https://www.aoakley.com/articles/stereo-test.mp3 -O - | mpg123 -
```

### 5. Main Application Setup

Clone and set up the main application:

```bash
cd ~/
git clone https://github.com/kkestell/rfid-toy
cd rfid-toy
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Running the Application

To start the application:

```bash
cd src
python server.py
```

### Systemd Unit

`/etc/systemd/system/rfid-music-player.service`:

```ini
[Unit]
Description=BronieBox Server
After=network.target

[Service]
Type=simple
User=kyle
ExecStart=/home/kyle/rfid-music-player/.venv/bin/python /home/kyle/rfid-music-player/src/server.py
WorkingDirectory=/home/kyle/rfid-music-player/src
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable rfid-music-player
sudo systemctl start rfid-music-player
sudo systemctl status rfid-music-player
journalctl -u rfid-music-player
```
