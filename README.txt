# Create directory
mkdir /etc/restic/

# Install restic and pigz
apt install restic pigz

# save config.env file to /etc/restic/config.env location

# Update values in "config.env" file

# place the backup script to /etc/restic/wordpress-backup.sh

# Setup cron (Everyday at 2AM)
0 2 * * * /bin/bash /etc/restic/wordpress-backup.sh >/dev/null 2>&1

# How to get TELEGRAM_TOKEN and TELEGRAM_CHAT_ID

> Open "@BotFather" chat 
> msg "/newbot"
> Enter "botname"
> Enter unique "Bot username" end with "bot" like "my_new_bot"
> You will get "TELEGRAM_TOKEN"

# to get "TELEGRAM_CHAT_ID" follow below steps 
1. start the bot by clicking botname listed on "@BotFather" chat
2. Client on "Startbot"
3. open https://api.telegram.org/bot{TELEGRAM_TOKEN}/getUpdates
4. Check below section
"chat":{"id":6684144949,"first_name":"Joy","username":"joypul","type":"private"}
5. the "id" under chat section is "TELEGRAM_CHAT_ID"
6. if you get empty respond, just send a msg to the bot and refresh the page.