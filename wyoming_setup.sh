#!/bin/bash
YELLOW='\033[0;33m' #Yellow Text
NC='\033[0m' #No Color

# Lets update the system.
updateme () {
  echo -e "\n${YELLOW}Setting our Rasberry Pi to be $satName\n${NC}"
  apt update
  apt dist-upgrade -y
  apt autoremove -y
  apt autoclean -y
}

# Lets set our Raspberry PI Satellite Designation (ie. HAsat3)
set_new_hostname () {
  echo -e "\n${YELLOW}Setting our Rasberry Pi to be $satName\n${NC}"
  daHost=$(cat /etc/hostname)
  echo -e $satName > /etc/hostname
  sed -i 's/127.0.1.1       $daHost/127.0.1.1       $satName/g' /etc/hosts
}

# Lets get our prereq's and setups downloaded.
satellite_setup () {
  echo -e "\n${YELLOW}Getting necessary files to install Wyoming Protocols\n${NC}"
  sudo apt-get update
  sudo apt-get install --no-install-recommends git python3-venv -y

  # Lets get our Wyoming Satellite code
  cd /home/pi
  git clone https://github.com/rhasspy/wyoming-satellite.git
  cd wyoming-satellite/
}

# Lets install Respeaker Hat Drivers
respeaker_setup () {
  echo -e "\n${YELLOW}Installing Respeak drivers. You will need a reboot to finalize.\n${NC}"
  bash /home/pi/wyoming-satellite/etc/install-respeaker-drivers.sh
}

wyoming_install () {
  echo -e "\n${YELLOW}Setting up Wyoming Protocols...\n${NC}"
  cd /home/pi/wyoming-satellite
  python3 -m venv .venv
  .venv/bin/pip3 install --upgrade pip
  .venv/bin/pip3 install --upgrade wheel setuptools
  .venv/bin/pip3 install -f 'https://synesthesiam.github.io/prebuilt-apps/' -r requirements.txt -r requirements_audio_enhancement.txt -r requirements_vad.txt
}

respeak_led_install () {
  echo -e "\n${YELLOW}Setting up Respeak Hat LEDs...\n${NC}"
  apt install python3-spidev python3-gpiozero -y
  cd /home/pi/wyoming-satellite/examples
  python3 -m venv --system-site-packages .venv
  .venv/bin/pip3 install --upgrade pip
  .venv/bin/pip3 install --upgrade wheel setuptools
  .venv/bin/pip3 install 'wyoming==1.5.2'
}

wyoming_start () {
  echo -e "\n${YELLOW}Starting Wyoming without Respeak.\n${NC}"
  script/run --debug --name '$satName' --uri 'tcp://0.0.0.0:10700' --mic-command 'arecord -D plughw:CARD=Microphones,DEV=0 -r 16000 -c 1 -f S16_LE -t raw' --snd-command 'aplay -D plughw:CARD=Headphones,DEV=0 -r 22050 -c 1 -f S16_LE -t raw'
}

wyoming_respeak_start () {
  echo -e "\n${YELLOW}Starting Wyoming with Respeak.\n${NC}"
  script/run --debug --name '$satName' --uri 'tcp://0.0.0.0:10700' --mic-command 'arecord -D plughw:CARD=seeed2micvoicec,DEV=0 -r 16000 -c 1 -f S16_LE -t raw' --snd-command 'aplay -D plughw:CARD=seeed2micvoicec,DEV=0 -r 22050 -c 1 -f S16_LE -t raw'
}

wyoming_service () {
  # Lets set up a system service for Wyoming
  echo -e "\n${YELLOW}Creating Wyoming Service.\n${NC}"
  echo -e "[Unit]\n" > /etc/systemd/system/wyoming-satellite.service
  echo -e "Description=Wyoming Satellite\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "Wants=network-online.target\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "After=network-online.target\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "[Service]\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "Type=simple\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "ExecStart=/home/pi/wyoming-satellite/script/run --name '$satName' --uri 'tcp://0.0.0.0:10700' --mic-command 'arecord -D plughw:CARD=microphones,DEV=0 -r 16000 -c 1 -f S16_LE -t raw' --snd-command 'aplay -D plughw:CARD=headphones,DEV=0 -r 22050 -c 1 -f S16_LE -t raw'" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "WorkingDirectory=/home/pi/wyoming-satellite\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "Restart=always\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "RestartSec=1\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "[Install]\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "WantedBy=default.target\n" >> /etc/systemd/system/wyoming-satellite.service
  systemctl enable wyoming-satellite.service
}

wyoming_respeak_service () {
  # Lets set up a system service for Wyoming
  echo -e "\n${YELLOW}Creating Wyoming Respeak Service\n${NC}"
  echo -e "[Unit]\n" > /etc/systemd/system/wyoming-satellite.service
  echo -e "Description=Wyoming Satellite\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "Wants=network-online.target\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "After=network-online.target\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "Requires=2mic_leds.service\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "[Service]\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "Type=simple\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "ExecStart=/home/pi/wyoming-satellite/script/run --name '$satName' --uri 'tcp://0.0.0.0:10700' --mic-command 'arecord -D plughw:CARD=seeed2micvoicec,DEV=0 -r 16000 -c 1 -f S16_LE -t raw' --snd-command 'aplay -D plughw:CARD=seeed2micvoicec,DEV=0 -r 22050 -c 1 -f S16_LE -t raw' --event-uri 'tcp://127.0.0.1:10500'" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "WorkingDirectory=/home/pi/wyoming-satellite\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "Restart=always\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "RestartSec=1\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "[Install]\n" >> /etc/systemd/system/wyoming-satellite.service
  echo -e "WantedBy=default.target\n" >> /etc/systemd/system/wyoming-satellite.service
  systemctl enable wyoming-satellite.service
}

led_control_service () {
  # Lets set up system service for the LED lights
  echo -e "\n${YELLOW}Creating LED Service.\n${NC}"
  echo -e "[Unit]\n" > /etc/systemd/system/2mic_leds.service
  echo -e "Description=2Mic LEDs Service\n" >> /etc/systemd/system/2mic_leds.service
  echo -e "\n" >> /etc/systemd/system/2mic_leds.service
  echo -e "[Service]\n" >> /etc/systemd/system/2mic_leds.service
  echo -e "Type=simple\n" >> /etc/systemd/system/2mic_leds.service
  echo -e "ExecStart=/home/pi/wyoming-satellite/examples/.venv/bin/python3 2mic_service.py --uri 'tcp://127.0.0.1:10500'\n" >> /etc/systemd/system/2mic_leds.service
  echo -e "WorkingDirectory=/home/pi/wyoming-satellite/examples\n" >> /etc/systemd/system/2mic_leds.service
  echo -e "Restart=always\n" >> /etc/systemd/system/2mic_leds.service
  echo -e "RestartSec=1\n" >> /etc/systemd/system/2mic_leds.service
  echo -e "\n" >> /etc/systemd/system/2mic_leds.service
  echo -e "[Install]\n" >> /etc/systemd/system/2mic_leds.service
  echo -e "WantedBy=default.target\n" >> /etc/systemd/system/2mic_leds.service
  systemctl enable 2mic_leds.service
}

# Lets check if we received out Satellites name, if so set to variable satName.
if [ $1 -n ]
then
  echo -e "Please add this Satellites name when calling command. ie) sudo ./wyoming-setup.sh HAsat1"
fi
satName=$1

read -p 'Are you using the respeak hat? (y or n)' respeak
if [[ $respeak == 'y' ]]
then
  set_new_hostname
  updateme
  satellite_setup
  respeaker_setup
  wyoming_install
  #wyoming_respeak_start
  wyoming_respeak_service
  respeak_led_install
  led_control_service
  systemctl daemon-reload
  systemctl restart wyoming-satellite.service
  systemctl start 2mic_leds.service
else
  set_new_hostname
  updateme
  satellite_setup
  wyoming_install
  #wyoming_start
  wyoming_service
  systemctl daemon-reload
  systemctl restart wyoming-satellite.service
fi
echo -e "Okay, all set.  Better give this guy a reboot!"
exit
