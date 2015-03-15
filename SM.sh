#!/system/bin/mksh
# SM.sh -- Enable ServiceMode (FieldTest) RF menu on Qualcomm based phones
# ---------------------------------------------------------------------
# Verified:     Samsung Galaxy S4-mini (GT-I9195) and others...
# Author:       E:V:A 
# Install:      cp SM.sh /system/xbin/SM.sh
#               chmod 777 /system/xbin/SM.sh
# Usage:        ./SM.sh         (as root)
# Note:         To enable all test features, you may need a special:
#               Factory SIM with IMSI:  "999999999999999"
#               Test SIM with IMSI:     "45001" or "00101"
# ---------------------------------------------------------------------
echo "Sit back and enjoy the ride!"

# Disable Factory Keystring block
echo -n "OFF" >/efs/FactoryApp/keystr'
# Enable carrier Hidden Menu:
echo -n "ON" >/efs/carrier/HiddenMenu
# Enable Factory Mode (may require Factory SIM)
echo -n "ON" >/efs/FactoryApp/factorymode

# Clear all logcat buffers
logcat -c -b main -b system -b radio -b events

# Send secret code to start field test app: /system/app/ServiceModeApp_RIL.apk
am broadcast -a android.provider.Telephony.SECRET_CODE -d android_secret_code://0011
sleep 5

# [MENU] "Back" 
input keyevent 82       # KEYCODE_MENU (menu button)
input keyevent 20       # KEYCODE_DPAD_DOWN (down)
input keyevent 20       # 
input keyevent 23       # KEYCODE_DPAD_CENTER (select)

# [MENU] "Key Input" + "Q0" + [OK]
input keyevent 82       # menu
input keyevent 20       # down
input keyevent 20       # down 
input keyevent 23       # select
input text "Q0"         # The magic string "Q<submenu>"
input keyevent 20       # down  (this highlights the OK button)
input keyevent 23       # center (this selects the highlighted item [OK button])

echo -en "\nDone!\nNow starting logcat... Use CTRL+\\ to quit.\n\n"
# Activate the vibrator for 250 ms.
echo 250 >/sys/devices/virtual/timed_output/vibrator/enable

# Read ServiceMenu wrapper from logcat:
logcat -b main -s ServiceModeApp_RIL:V isKeyStringBlocked:V
# ---------------------------------------------------------------------
