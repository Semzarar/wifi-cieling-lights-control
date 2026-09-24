## README MADE BY CLAUDE BECAUSE IM LAZY. THIS IS NOT MY WRITING
# Wifi Cieling Lights Control

Control your tinytuya wifi ceiling lights (cieling lights) from a laptop. Local only, no cloud after setup, no phone app.

Two scripts:

- `lights.py` is a command line tool. Turn lights on and off, set white, warmth, brightness and colour, on one bulb or all of them at once.
- `lights_menu.sh` is a point and click menu built with yad. It has presets and desktop notifications.

Made for Tuya based wifi lights, the ones that use the Smart Life or Tuya Smart app. It talks to the bulbs over your local network with [TinyTuya](https://github.com/jasonacox/tinytuya).

## What it can do

| Command | What it does |
| --- | --- |
| `on` / `off` | Power the light |
| `white [brightness] [warmth]` | White mode. Brightness 10 to 1000 (default 1000). Warmth 0 is cool, 1000 is warm (default 500) |
| `colour R G B [brightness]` | Set a colour. R, G and B are 0 to 255 |
| `red` / `green` / `blue` | Quick colours |
| `bright` | Full brightness, cool white |
| `dim` | Low brightness, warm white |
| `disco` | Switch to the bulb's scene mode |
| `status` | Print the raw status of the bulb |

Target one light by name (`BL`, `BR`, `FL`, `FR`) or use `ALL`. With `ALL` every bulb gets the command at the same time.

## Requirements

- Python 3
- TinyTuya
- For the menu: bash, `yad` and `notify-send`, on Linux

`lights.py` runs anywhere Python runs. The menu needs Linux.

```bash
pip install tinytuya

# Arch
sudo pacman -S yad libnotify
# Debian / Ubuntu
sudo apt install yad libnotify-bin
# Fedora
sudo dnf install yad libnotify
```

## Setup

### 1. Get your device IDs and local keys

Each bulb needs its device ID and local key. TinyTuya has a wizard that pulls them from the Tuya developer console:

```bash
python3 -m tinytuya wizard
```

It asks for your Tuya IoT Platform API details and writes out a list of your devices with their keys. Find the bulb IPs with:

```bash
python3 -m tinytuya scan
```

Give your bulbs fixed IPs in your router so they never change.

### 2. Add your lights

Open `lights.py` and edit the `BULBS` dictionary. The name is up to you, the value is `(device id, ip, local key)`:

```python
BULBS = {
    'BL': ('your_device_id', '192.168.1.10', 'your_local_key'),
    'BR': ('your_device_id', '192.168.1.11', 'your_local_key'),
    'FL': ('your_device_id', '192.168.1.12', 'your_local_key'),
    'FR': ('your_device_id', '192.168.1.13', 'your_local_key'),
}
```

The bulbs use protocol version 3.5. If yours are older, change `d.set_version(3.5)` to 3.4 or 3.3.

### 3. Make it runnable

The first line of `lights.py` points at a Python path on my machine. Change it to:

```python
#!/usr/bin/env python3
```

Then:

```bash
chmod +x lights.py lights_menu.sh
```

### 4. Point the menu at the script

In `lights_menu.sh` set `LIGHTS_PY` to where you put `lights.py`:

```bash
LIGHTS_PY="/home/you/lights.py"
```

If you renamed the lights, update the lists of names in the menu too. They are hardcoded as `BL`, `BR`, `FL` and `FR`.

## Usage

Command line:

```bash
./lights.py on ALL
./lights.py off FL
./lights.py white ALL 800 300
./lights.py colour BR 255 0 128 700
./lights.py dim ALL
./lights.py status BL
```

Menu:

```bash
./lights_menu.sh
```

Pick all lights, a single light or several, then choose white, colour or on and off. Bind it to a keyboard shortcut in your desktop or window manager and you can change the lights without leaving your laptop.

## Presets

Presets are stored in `~/.config/lights/presets.json`. Each preset is a name with a list of commands, exactly as you would give them to `lights.py`:

```json
{
  "movie": ["dim ALL", "colour FL 255 60 0 300"],
  "work": ["white ALL 1000 0"]
}
```

Presets show up in the menu with a star. Every command in a preset runs at the same time.

## Troubleshooting

- **Timeout or error on a bulb.** Check the IP, make sure your laptop is on the same network, and close any other app or script talking to that bulb.
- **Wrong or garbled response.** Try a different protocol version (3.3, 3.4 or 3.5).
- **It worked, then stopped.** Re pairing a bulb in the Smart Life app gives it a new local key. Run the wizard again and update `BULBS`.

## Keep your keys private

Local keys let anyone on your network control your bulbs. Do not commit them to a public repo. If you fork this, keep your `BULBS` values out of your commits.

## License

GPL 3.0. See [LICENSE](LICENSE).
