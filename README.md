![HealthAlert graphic](https://github.com/cwang360/HealthAlert/blob/main/HealthAlert.png)
# HealthAlert
Safety health wearable and app tailored to the elderly, people with dangerous health conditions, and people who suffer from memory loss.

Many of our grandparents or parents may live alone, and their safety is our first priority. As people get older, they are more susceptible to dangerous health conditions and memory loss. HealthAlert helps them take care of themselves in different environments, like hot or humid climates, and immediately alert close family members if the wearable detects alarming events, like a seizure or fall.

## Capabilities
The main goal of HealthAlert is to help those susceptible to medical conditions or memory loss take care of themselves more easily and alert close family members of alarming motions. The device has the following capabilities:
- **Environment sensing:** The temperature and humidity data captured/processed from the sensors on the *Arduino Nano 33 BLE Sense* are sent to the mobile app connected through Bluetooth Low Energy (BLE). If the temperature or humidity are at unhealthy levels (too high or too low), notifications are sent to the user to remind them to drink water, wear a coat, limit exercise, etc. If the temperature and humidity levels are healthy, the user is encouraged to exercise.
- **Fall detection:** If the wearable detects sudden acceleration that lasts for a couple clock cycles (fall) followed by a 10+ second period of no movement, an SMS message is automatically sent to the user-defined phone number (e.g. a close family member) that notifies them about the situation. On the hardware side, a buzzer starts beeping after the fall is detected to allow the user to respond by moving, indicating they can get back up. If the user does not move for 10+ seconds after the fall is detected, a different buzzer alarm sounds as the SMS message is sent.
- **Seizure/severe tremor detection:** If the wearable detects severe tremor motion that could indicate a seizure, the buzzer alarm goes off and an SMS message is automatically sent to the user-defined phone number. 
- **Reminders when exiting home:** Using geofences, the associated app will send reminders the wearer might want. For example, if you constantly forget to wear a mask or forget your papers or breakfast, this app will remind you to gather your papers, wear a mask, or eat breakfast before you leave your home too far.

## Details
- The wearable itself is an Arduino Nano 33 BLE Sense mounted on a small breadboard with a buzzer and LEDs to indicate connectivity/errors with sensors (green = working, connected; yellow = connecting...; red = problem with initializing BLE or sensors). Straps are used to mount the device on the user's arm. The Arduino microcontroller was programmed in the Arduino IDE to continuously retrieve sensor /status data to send to the app and detect falls or seizures. 
- Fall detection is handled by an algorithm that detects total acceleration from the onboard IMU that goes over a certain threshold multiple clock cycles in a row, followed by a period of no movement (acceleration below another threshold). Seizure/tremor detection uses machine learning to differentiate between seizure-like severe tremors and normal or noise movement, like waving and scrubbing dishes. Samples simulating seizure-like tremors and normal movement were collected and used to train a model on Google Colab using Tensor Flow Lite to obtain a model header file that can be used for classification in the main Arduino code.
- The app was created in Flutter, and the flutter_reactive_ble package was used to communicate with the Arduino through Bluetooth Low Energy. The app is user-friendly and displays current temperature/humidity data and status information (fall/seizure/weather). In the settings menu, the user can add the phone number to send an SMS to when a fall or seizure is detected. The sms_maintained package is used to automatically send the SMS.

## In This Repository
- The Arduino sketch for the Arduino Nano 33 BLE Sense is found in the bluetooth_wearable_combined folder. The model.h file is the header file that contains the trained model for classifying severe tremors.
- The Flutter project is found in the wearable_butler_app folder.

***This project was submitted to the HackUMass hackathon in December 2020.***
