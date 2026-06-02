#!/home/semzarar/SSD2/code/PycharmProjects/PythonProject/.venv/bin/python3
##
## Author : @semzarar
## Tuya bulb controller - fully local, no cloud after setup
##

import tinytuya
import sys
import threading

BULBS = {
    'BL': ('eba183918f1d525b93rehd', '192.168.18.24', '#Mt2eGzPh2HRuh:~'),
    'BR': ('ebafe37ecc8409c1e2xqlg', '192.168.18.25', 'W[5a*`v9egL5qMB@'),
    'FL': ('eb54bba828bef5c5991aqb', '192.168.18.23', '#iNV.=s{zSew<Y*8'),
    'FR': ('eb6e7b4764536a46b2jhqb', '192.168.18.22', 'EvO4rl+6kujI+6^w'),
}

def get_bulb(name):
    id, ip, key = BULBS[name.upper()]
    d = tinytuya.BulbDevice(id, ip, key)
    d.set_version(3.5)
    d.set_socketTimeout(3)
    return d

def control(name, cmd, args):
    try:
        d = get_bulb(name)
        if cmd == 'on':
            d.turn_on()
        elif cmd == 'off':
            d.turn_off()
        elif cmd == 'white':
            brightness = int(args[0]) if args else 1000
            warmth = int(args[1]) if len(args) > 1 else 500
            d.turn_on()
            d.set_mode('white')
            d.set_brightness(brightness)
            d.set_colourtemp(warmth)
        elif cmd == 'colour':
            r, g, b = int(args[0]), int(args[1]), int(args[2])
            brightness = int(args[3]) if len(args) > 3 else 1000
            d.turn_on()
            d.set_colour(r, g, b)
            d.set_brightness(brightness)
        elif cmd == 'red':
            d.turn_on(); d.set_colour(255, 0, 0)
        elif cmd == 'green':
            d.turn_on(); d.set_colour(0, 255, 0)
        elif cmd == 'blue':
            d.turn_on(); d.set_colour(0, 0, 255)
        elif cmd == 'bright':
            d.turn_on(); d.set_mode('white'); d.set_brightness(1000); d.set_colourtemp(0)
        elif cmd == 'dim':
            d.turn_on(); d.set_mode('white'); d.set_brightness(150); d.set_colourtemp(1000)
        elif cmd == 'disco':
            d.turn_on(); d.set_mode('scene')
        elif cmd == 'status':
            print(f"{name}: {d.status()}")
            return
        print(f"{name}: {cmd} ok")
    except Exception as e:
        print(f"{name}: error - {e}")

def run(cmd, target, *args):
    names = list(BULBS.keys()) if target.upper() == 'ALL' else [target.upper()]
    threads = [threading.Thread(target=control, args=(name, cmd, args)) for name in names]
    for t in threads: t.start()
    for t in threads: t.join()

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: lights.py <command> <target> [args...]")
        print("Commands: on off white colour red green blue bright dim disco status")
        print("Targets: BL BR FL FR ALL")
        sys.exit(1)
    cmd = sys.argv[1]
    target = sys.argv[2]
    args = sys.argv[3:]
    run(cmd, target, *args)
